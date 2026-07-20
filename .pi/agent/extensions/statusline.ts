/**
 * Statusline footer extension.
 *
 * Reproduces Claude Code's ~/.claude/statusline-command.sh inside pi:
 *   - context window usage bar + percentage + tokens used/size
 *   - Anthropic 5h / weekly (+ overage credit) usage bars with reset countdown
 *   - current model id and thinking level
 *   - git branch
 *
 * Rate-limit data source:
 *   Anthropic's undocumented OAuth usage endpoint
 *     GET https://api.anthropic.com/api/oauth/usage
 *     Authorization: Bearer <oauth access token>
 *     anthropic-beta: oauth-2025-04-20
 *   This is the same endpoint Claude Code's /usage command uses. It returns
 *   authoritative 5h + 7d utilization (0-100) with ISO reset times, plus
 *   extra_usage (overage credits). We read pi's OAuth access token from
 *   ~/.pi/agent/auth.json (pi keeps it refreshed) and poll the endpoint on
 *   session start and after each agent turn settles. No background timers.
 *
 *   Unlike the `anthropic-ratelimit-unified-*` response headers (which only
 *   exposed the overage window on this account), this endpoint always breaks
 *   out the 5h and weekly windows.
 *
 * Toggle with /statusline. Manual refresh with /statusline-refresh.
 * Placement: ~/.pi/agent/extensions/statusline.ts (auto-discovered; /reload).
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type TUI,
	truncateToWidth,
	visibleWidth,
} from "@earendil-works/pi-tui";

// ---- ANSI colors (dim, to match the original statusline look) ----
const RESET = "\x1b[0m";
const CYAN = "\x1b[2;36m";
const YELLOW = "\x1b[2;33m";
const MAGENTA = "\x1b[2;35m";
const GREEN = "\x1b[2;32m";
const RED = "\x1b[2;31m";
const DIM = "\x1b[2m";

const USAGE_URL = "https://api.anthropic.com/api/oauth/usage";
const AUTH_PATH = join(homedir(), ".pi", "agent", "auth.json");
const MIN_FETCH_INTERVAL_MS = 15_000;

interface RateWindow {
	/** short display label, e.g. "5h", "Wk", "ovg" */
	label: string;
	/** 0-100 percent */
	pct: number;
	/** unix seconds when the window resets, or null */
	reset: number | null;
	/** ANSI color for the bar */
	color: string;
}

// Latest usage snapshot from the OAuth usage endpoint.
const rate: { windows: RateWindow[]; error: string | null } = {
	windows: [],
	error: null,
};
let lastFetch = 0;
let inFlight = false;

/** raw token count -> human readable (e.g. 1.0M, 128k) */
function fmtTokens(n: number | null | undefined): string {
	if (n === null || n === undefined) return "0";
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 1000) return `${Math.round(n / 1000)}k`;
	return `${n}`;
}

/** seconds remaining -> "3h41m" or "3d16h" */
function fmtDuration(secs: number | null): string {
	if (secs === null || secs <= 0) return "";
	const days = Math.floor(secs / 86400);
	const hours = Math.floor((secs % 86400) / 3600);
	const mins = Math.floor((secs % 3600) / 60);
	return days > 0 ? `${days}d${hours}h` : `${hours}h${mins}m`;
}

/** percentage (0-100) -> a filled/empty bar of the given width */
function bar(pct: number | null, width = 8): string {
	if (pct === null) return "\u2504".repeat(width);
	let filled = Math.round((pct / 100) * width);
	if (filled > width) filled = width;
	if (filled < 0) filled = 0;
	return "\u2501".repeat(filled) + "\u2504".repeat(width - filled);
}

/** ISO 8601 -> unix seconds, or null */
function isoToUnix(iso: unknown): number | null {
	if (typeof iso !== "string") return null;
	const ms = Date.parse(iso);
	return Number.isNaN(ms) ? null : Math.floor(ms / 1000);
}

function readAccessToken(): string | null {
	try {
		const raw = readFileSync(AUTH_PATH, "utf8");
		const data = JSON.parse(raw) as {
			anthropic?: { access?: string; expires?: number };
		};
		const token = data.anthropic?.access;
		return typeof token === "string" && token.length > 0 ? token : null;
	} catch {
		return null;
	}
}

interface UsageWindow {
	utilization?: number;
	resets_at?: string;
	is_enabled?: boolean;
}

/** Fetch the OAuth usage endpoint and update `rate`. Returns true on change. */
async function fetchUsage(): Promise<boolean> {
	if (inFlight) return false;
	if (Date.now() - lastFetch < MIN_FETCH_INTERVAL_MS) return false;
	const token = readAccessToken();
	if (!token) {
		rate.error = "no token";
		return false;
	}
	inFlight = true;
	lastFetch = Date.now();
	try {
		const controller = new AbortController();
		const timer = setTimeout(() => controller.abort(), 4000);
		const res = await fetch(USAGE_URL, {
			headers: {
				authorization: `Bearer ${token}`,
				"anthropic-beta": "oauth-2025-04-20",
			},
			signal: controller.signal,
		});
		clearTimeout(timer);
		if (!res.ok) {
			rate.error = `HTTP ${res.status}`;
			return false;
		}
		const data = (await res.json()) as {
			five_hour?: UsageWindow;
			seven_day?: UsageWindow;
			extra_usage?: UsageWindow;
		};
		const windows: RateWindow[] = [];
		const push = (
			w: UsageWindow | undefined,
			label: string,
			color: string,
			gate = true,
		) => {
			if (!w || !gate || typeof w.utilization !== "number") return;
			windows.push({
				label,
				pct: w.utilization,
				reset: isoToUnix(w.resets_at),
				color,
			});
		};
		push(data.five_hour, "5h", YELLOW);
		push(data.seven_day, "Wk", MAGENTA);
		push(
			data.extra_usage,
			"ovg",
			RED,
			data.extra_usage?.is_enabled === true &&
				(data.extra_usage?.utilization ?? 0) > 0,
		);
		rate.windows = windows;
		rate.error = null;
		return true;
	} catch (err) {
		rate.error = err instanceof Error ? err.name : "fetch failed";
		return false;
	} finally {
		inFlight = false;
	}
}

export default function (pi: ExtensionAPI) {
	let enabled = true;
	// Live TUI handle so async usage updates can trigger a footer re-render.
	let currentTui: TUI | undefined;

	const refresh = async () => {
		const changed = await fetchUsage();
		if (changed) currentTui?.requestRender();
	};

	const install = (ctx: Parameters<Parameters<typeof pi.on>[1]>[1]) => {
		ctx.ui.setFooter((tui, _theme, footerData) => {
			currentTui = tui;
			const unsub = footerData.onBranchChange(() => tui.requestRender());
			return {
				dispose() {
					unsub();
					if (currentTui === tui) currentTui = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const now = Math.floor(Date.now() / 1000);

					// ---- context window ----
					const usage = ctx.getContextUsage();
					const used = usage?.tokens ?? null;
					const size = usage?.contextWindow ?? 0;
					const pct = usage?.percent ?? null;
					const pctDisp = pct === null ? "--" : `${Math.round(pct)}`;
					const ctxStr =
						`${CYAN}window ${bar(pct)} ${pctDisp}% ` +
						`${fmtTokens(used)}/${fmtTokens(size)}${RESET}`;

					// ---- rate limits ----
					let limitStr: string;
					if (rate.windows.length === 0) {
						const note = rate.error ? ` ${rate.error}` : "";
						limitStr = `${DIM}limit ${bar(null)} --%${note}${RESET}`;
					} else {
						limitStr = rate.windows
							.map((w) => {
								const rem = fmtDuration(
									w.reset === null ? null : w.reset - now,
								);
								const remStr = rem ? ` ${rem}` : "";
								return `${w.color}${w.label} ${bar(w.pct)} ${Math.round(w.pct)}%${remStr}${RESET}`;
							})
							.join("  ");
					}

					// ---- model / thinking ----
					const modelId = ctx.model?.id ?? "no-model";
					let thinking = "";
					try {
						const lvl = pi.getThinkingLevel?.();
						if (lvl && lvl !== "off") thinking = ` (${lvl})`;
					} catch {
						/* getThinkingLevel not available here */
					}
					const branch = footerData.getGitBranch();
					const branchStr = branch ? `${DIM} \u2387 ${branch}${RESET}` : "";
					const modelStr = `${GREEN}${modelId}${thinking}${RESET}`;

					const left = `${ctxStr}  ${limitStr}`;
					const right = modelStr + branchStr;
					const gap = Math.max(
						1,
						width - visibleWidth(left) - visibleWidth(right),
					);
					return [truncateToWidth(left + " ".repeat(gap) + right, width)];
				},
			};
		});
	};

	pi.registerCommand("statusline", {
		description: "Toggle the custom statusline footer",
		handler: async (_args, ctx) => {
			enabled = !enabled;
			if (enabled) {
				install(ctx);
				void refresh();
				ctx.ui.notify("Statusline footer enabled", "info");
			} else {
				ctx.ui.setFooter(undefined);
				ctx.ui.notify("Default footer restored", "info");
			}
		},
	});

	pi.registerCommand("statusline-refresh", {
		description: "Force-refresh Anthropic usage in the statusline",
		handler: async (_args, ctx) => {
			lastFetch = 0; // bypass throttle
			const changed = await fetchUsage();
			if (changed) currentTui?.requestRender();
			ctx.ui.notify(
				rate.error ? `Usage refresh failed: ${rate.error}` : "Usage refreshed",
				rate.error ? "warning" : "info",
			);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		if (!enabled) return;
		install(ctx);
		void refresh();
	});

	// Usage changes after each turn; refresh when the agent run settles.
	pi.on("agent_settled", async () => {
		if (enabled) void refresh();
	});
}
