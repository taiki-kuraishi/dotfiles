import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import {
	basename,
	dirname,
	isAbsolute,
	join,
	matchesGlob,
	relative,
	resolve,
} from "node:path";
import { homedir } from "node:os";

/**
 * auto-agents-md
 *
 * agent が read / write / edit で触ったファイルを起点に、参考コンテキストを自動注入する。
 *   1. 上位ディレクトリ階層（HOME まで）の AGENTS.md / Agent.md / CLAUDE.md / Claude.md
 *   2. 同階層の .claude/rules/**\/*.md（フロントマターの glob が操作ファイルに一致するもの。
 *      フロントマター無しは無条件）
 *   3. read した指示ファイル、および起動時 context ファイルの `@path` import を再帰展開
 *      （Claude Code の @import 相当。拡張子問わず・実在ファイルのみ・循環検出あり）
 * 一度注入したファイルは二度と注入しない。
 */

const AGENT_FILENAMES = ["AGENTS.md", "Agent.md", "CLAUDE.md", "Claude.md"];
const PATH_TOOLS = ["read", "write", "edit"] as const;
const MAX_DEPTH = 5;

export default function (pi: ExtensionAPI) {
	const HOME = resolve(homedir());
	const loaded = new Set<string>(); // 注入済み（重複注入防止）
	const expanded = new Set<string>(); // import 解析済み（再帰の循環/重複防止）
	let seeded = false; // セッション履歴から loaded をシード済みか

	/** current が HOME 以下（HOME 自身を含む）か */
	function withinHome(current: string): boolean {
		return current === HOME || current.startsWith(`${HOME}/`);
	}

	/** 操作パスの起点ディレクトリ（ファイルなら親、ディレクトリならそこ） */
	function startDir(abs: string): string {
		try {
			return statSync(abs).isDirectory() ? abs : dirname(abs);
		} catch {
			return dirname(abs); // 未作成（write 新規など）は親を起点に
		}
	}

	/** 絶対パスが展開起点となる指示ファイルか（大文字小文字問わず） */
	function isInstructionFile(abs: string): boolean {
		const name = basename(abs).toLowerCase();
		if (["agents.md", "agent.md", "claude.md"].includes(name)) return true;
		return /\/\.claude\/rules\/.*\.md$/i.test(abs.replace(/\\/g, "/"));
	}

	/**
	 * pi の skill ファイルか（skill 呼び出し時は周辺指示ファイルを注入しない）。
	 * pi の skill 配置ルールに準拠:
	 *   - SKILL.md を含むディレクトリ型 skill（全 root / パッケージをカバー）
	 *   - ~/.pi/agent/skills/ ・ .pi/skills/ 直下の単体 .md skill
	 */
	function isSkillFile(abs: string): boolean {
		const norm = abs.replace(/\\/g, "/");
		if (basename(norm) === "SKILL.md") return true;
		return (
			norm.startsWith(`${HOME}/.pi/agent/skills/`) ||
			norm.startsWith(`${HOME}/.agents/skills/`) ||
			/\/\.pi\/skills\//.test(norm) ||
			/\/\.agents\/skills\//.test(norm)
		);
	}

	// ---- AGENTS.md 系の探索 ----------------------------------------------------

	function collectAgentFiles(dir: string): string[] {
		const found: string[] = [];
		let current = resolve(dir);
		while (withinHome(current)) {
			for (const name of AGENT_FILENAMES) {
				const candidate = join(current, name);
				if (!loaded.has(candidate) && existsSync(candidate))
					found.push(candidate);
			}
			if (current === HOME) break;
			const parent = dirname(current);
			if (parent === current) break;
			current = parent;
		}
		return found;
	}

	// ---- .claude/rules 系の探索 ------------------------------------------------

	function stripQuotes(v: string): string {
		return v.replace(/^['"]|['"]$/g, "").trim();
	}

	/**
	 * フロントマターから glob 一覧を抽出。hasFilter=false は「制限なし＝無条件ロード」。
	 * globs: / paths: の単一・インライン配列・ブロックリスト、クォート有無に対応。
	 */
	function parseRuleGlobs(content: string): {
		globs: string[];
		hasFilter: boolean;
	} {
		const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
		if (!m) return { globs: [], hasFilter: false };
		const lines = m[1].split(/\r?\n/);
		const globs: string[] = [];
		let hasFilter = false;

		for (let i = 0; i < lines.length; i++) {
			const key = lines[i].match(/^(globs|paths)\s*:\s*(.*)$/);
			if (!key) continue;
			hasFilter = true;
			const rest = key[2].trim();

			if (rest === "") {
				// 直後のブロックリスト（- item）
				for (let j = i + 1; j < lines.length; j++) {
					const item = lines[j].match(/^\s*-\s*(.+?)\s*$/);
					if (item) {
						const v = stripQuotes(item[1]);
						if (v) globs.push(v);
						continue;
					}
					if (lines[j].trim() === "") continue;
					break;
				}
			} else if (rest.startsWith("[")) {
				for (const part of rest.replace(/^\[|\]$/g, "").split(",")) {
					const v = stripQuotes(part);
					if (v) globs.push(v);
				}
			} else {
				const v = stripQuotes(rest);
				if (v) globs.push(v);
			}
		}
		return { globs, hasFilter };
	}

	/** 操作ファイル abs が root / cwd 相対のいずれかで glob 群に一致するか */
	function pathMatches(
		abs: string,
		root: string,
		cwd: string,
		globs: string[],
	): boolean {
		const candidates = new Set<string>();
		for (const base of [root, cwd]) {
			const rel = relative(base, abs);
			if (rel && !rel.startsWith("..") && !isAbsolute(rel)) candidates.add(rel);
		}
		for (const g of globs) {
			for (const rel of candidates) {
				try {
					if (matchesGlob(rel, g)) return true;
				} catch {
					/* invalid glob */
				}
			}
		}
		return false;
	}

	function stripFrontmatter(content: string): string {
		return content.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n?/, "").trimStart();
	}

	/** 操作パスに適用すべき .claude/rules ファイルを収集 */
	function collectRuleFiles(abs: string, dir: string, cwd: string): string[] {
		const found: string[] = [];
		let current = resolve(dir);
		while (withinHome(current)) {
			const rulesDir = join(current, ".claude", "rules");
			let entries: string[] = [];
			try {
				if (statSync(rulesDir).isDirectory()) {
					entries = readdirSync(rulesDir, { recursive: true }).filter(
						(f): f is string => typeof f === "string" && f.endsWith(".md"),
					);
				}
			} catch {
				/* no rules dir here */
			}

			for (const name of entries) {
				const file = join(rulesDir, name);
				if (loaded.has(file)) continue;
				let content: string;
				try {
					content = readFileSync(file, "utf8");
				} catch {
					continue;
				}
				const { globs, hasFilter } = parseRuleGlobs(content);
				if (!hasFilter || pathMatches(abs, current, cwd, globs))
					found.push(file);
			}

			if (current === HOME) break;
			const parent = dirname(current);
			if (parent === current) break;
			current = parent;
		}
		return found;
	}

	// ---- @import 展開 ----------------------------------------------------------

	/** `@path` import を抽出（コードスパン / コードブロックは除外） */
	function parseImports(content: string): string[] {
		const out: string[] = [];
		let inFence = false;
		for (const line of content.split(/\r?\n/)) {
			if (/^\s*(```|~~~)/.test(line)) {
				inFence = !inFence;
				continue;
			}
			if (inFence) continue;
			const noSpans = line.replace(/`[^`]*`/g, " ");
			const re = /(^|\s)@(\S+)/g;
			let m: RegExpExecArray | null;
			while ((m = re.exec(noSpans)) !== null) {
				const p = m[2].replace(/[),;:]+$/, "");
				if (p) out.push(p);
			}
		}
		return out;
	}

	/** import パスを絶対パスへ解決（~/ ・絶対・相対に対応） */
	function resolveImport(raw: string, baseDir: string): string {
		if (raw === "~") return HOME;
		if (raw.startsWith("~/")) return resolve(HOME, raw.slice(2));
		if (isAbsolute(raw)) return resolve(raw);
		return resolve(baseDir, raw);
	}

	/** file 内の import を再帰展開し、注入メッセージを collect へ渡す */
	function expandImports(
		file: string,
		ctx: ExtensionContext,
		depth: number,
		collect: (msg: string) => void,
	) {
		const abs = resolve(file);
		if (expanded.has(abs)) return;
		expanded.add(abs);
		if (depth > MAX_DEPTH) return;

		let content: string;
		try {
			content = readFileSync(abs, "utf8");
		} catch {
			return;
		}

		const baseDir = dirname(abs);
		for (const raw of parseImports(content)) {
			const target = resolveImport(raw, baseDir);
			try {
				if (!statSync(target).isFile()) continue; // 実在ファイルのみ
			} catch {
				continue;
			}
			const msg = buildInjection(target, ctx, { kind: "import" });
			if (msg) collect(msg);
			expandImports(target, ctx, depth + 1, collect);
		}
	}

	// ---- 注入 ------------------------------------------------------------------

	/** 注入メッセージを組み立てて返す（未読なら loaded に登録）。既注入/読めない場合は null。 */
	function buildInjection(
		file: string,
		ctx: ExtensionContext,
		opts: { strip?: boolean; kind?: "import" } = {},
	): string | null {
		if (loaded.has(file)) return null;
		loaded.add(file); // 読めても読めなくても二重注入を防ぐ

		let content: string;
		try {
			content = readFileSync(file, "utf8");
		} catch {
			return null;
		}
		if (opts.strip) content = stripFrontmatter(content);

		const label = opts.kind === "import" ? "(import) " : "";
		if (ctx.hasUI) ctx.ui.notify(`auto-agents-md: ${file}`, "info");
		return (
			`Hit! ${label}${basename(file)} : ${file}\n\n` +
			`<auto_context path="${file}">\n${content}\n</auto_context>`
		);
	}

	// ---- フック ----------------------------------------------------------------

	// 起動時 context ファイル（cwd の AGENTS.md 等）の @import を展開する。
	// このタイミングは agent がプロンプト処理を開始する直前で sendUserMessage が使えないため、
	// followUp ではなく before_agent_start の戻り値でメッセージ注入する。
	// 本体は pi が読み込み済みなので loaded に登録して本体注入はスキップし、import だけ展開する。
	// contextFiles は before_agent_start でしか取れないため session_start ではなくここで行う。
	// expanded/loaded の dedup により実質セッション初回の 1 回だけ展開される。
	pi.on("before_agent_start", (event, ctx) => {
		// 初回のみ: セッション履歴に既に存在する注入パスを loaded へシードする。
		// in-memory の loaded は reload / 別ターン / プロセス再起動で消えるが、
		// 履歴（ファイル永続）から復元すれば dedup がこれらをまたいで成立する。
		if (!seeded) {
			seeded = true;
			for (const e of ctx.sessionManager.getEntries()) {
				for (const m of JSON.stringify(e).matchAll(
					/auto_context path=\\"([^"\\]+)\\"/g,
				)) {
					loaded.add(m[1]);
				}
			}
		}

		const parts: string[] = [];
		for (const f of event.systemPromptOptions?.contextFiles ?? []) {
			if (!f?.path) continue;
			const abs = resolve(f.path);
			loaded.add(abs);
			if (isInstructionFile(abs))
				expandImports(abs, ctx, 0, (m) => parts.push(m));
		}
		if (parts.length === 0) return;
		return {
			message: {
				customType: "auto-agents-md",
				content: parts.join("\n\n"),
				display: true,
			},
		};
	});

	pi.on("tool_call", (event, ctx) => {
		let rawPath: string | undefined;
		let isRead = false;
		for (const tool of PATH_TOOLS) {
			if (isToolCallEventType(tool, event)) {
				rawPath = (event.input as { path?: string }).path;
				isRead = tool === "read";
				break;
			}
		}
		if (!rawPath) return;

		const abs = isAbsolute(rawPath) ? rawPath : resolve(ctx.cwd, rawPath);
		// skill 呼び出し（SKILL.md 等の read）は周辺指示ファイルを拾わない
		if (isSkillFile(abs)) return;
		const dir = startDir(abs);

		const parts: string[] = [];
		for (const f of collectAgentFiles(dir)) {
			const m = buildInjection(f, ctx);
			if (m) parts.push(m);
		}
		for (const f of collectRuleFiles(abs, dir, ctx.cwd)) {
			const m = buildInjection(f, ctx, { strip: true });
			if (m) parts.push(m);
		}
		// read した指示ファイルの @import を展開
		if (isRead && isInstructionFile(abs))
			expandImports(abs, ctx, 0, (m) => parts.push(m));
		// steer: 現ターンの tool 実行完了直後（次の LLM 呼び出し前）に届く。
		// steeringMode "one-at-a-time" でも 1 通で全ヒットが届くようイベント単位で束ねる。
		if (parts.length > 0)
			pi.sendUserMessage(parts.join("\n\n"), { deliverAs: "steer" });
	});
}
