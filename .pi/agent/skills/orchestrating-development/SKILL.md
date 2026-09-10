---
name: orchestrating-development
description: Use when the user asks to build, implement, refactor, or fix something in a git repo that needs a spec and plan before code — 「〜を実装して」「〜機能を作りたい」「issue #N をやって」「リファクタして」, "build X", "implement this". Also use when a session was started as a worker for a plan (「worker mode で」), when the user reports a hunk review is done (「レビュー終わった」), or asks to clean up a finished handoff (「片付けて」). Not for questions, spikes, or one-line fixes with no plan. Works in both Claude Code and pi sessions; tool names that differ between the two map per the correspondence table below (`ClaudeではX / piではY` の読み替えで両対応).
---

# Orchestrating development

superpowers (brainstorming → writing-plans → subagent-driven-development) を土台に、
**spec / plan を root session が書き、実装は herdr の worker session に委譲し、
user は hunk で PR をレビューする**流れに固定する。

Claude Code と pi の両方で使う。本文の手順は Claude Code を主文とし、pi では下の対応表・各節の注記（`ClaudeではX / piではY`）に従って読み替える。pi 等価物が未確定の箇所は「要確認」と書いた。

superpowers 本文と矛盾する箇所は**このスキルが優先**する
(`superpowers:using-superpowers` の "User instructions take precedence over skills" に依拠)。

## モード判定

| 状況 | モード |
| --- | --- |
| user が機能実装・修正を依頼した | **root** |
| 起動プロンプトに「worker mode で orchestrating-development」とある | **worker** |
| user が「レビュー終わった」と言った | root の §R6-6 へ |
| user が「片付けて」と言った | root の §R7 へ |

## 共通ポリシー

> 注意：あなたの主なタスクは分析、編排、検証です。具体的なタスクは可能な限り subagent（Opus または Sonnet。pi では対応表に従い `scout` / `researcher` / `worker` / `reviewer` など）に
> 実行させます。自分は要件の明確化、方案の分解、タスクの分配、結果の受け入れだけを行い、実装類の作業
> （大量のコード読み込み、コード執筆、テスト実行、批量修正）はすべて Agent ツールを使って subagent に
> 割り当てて実行させます。

**オーケストレータはコードを読まない・書かない。** 高いのは読むことであって書くことではない。

- 自分で読んでよいもの: spec、plan、subagent の報告、hunk のコメント、`.github/pull_request_template.md`、`AGENTS.md`（root と各ディレクトリ）と `.claude/rules/**` の見出し（pi ではさらに `~/.pi/agent/AGENTS.md`）。
- 自分で書いてよいもの: spec、plan、commit / PR のタイトルと本文、`AGENTS.md`（root / 各ディレクトリ）と `.claude/rules/**`（いずれも user 承認後）。
- 直接 tool 使用の上限（3コールルール）: コードベースへの読み書き・実行（read / bash / edit / write 等）は合計3コール以内の確認・参照に限定する。見込み3コール超、テスト・デバッグ、複数ファイルに跨る調査、大量出力が見込まれるコマンドは必ず subagent に出す。subagent の起動と user への質問は数えない。spec / plan 等の文書執筆は root の本務なので数えない。理由は root の context 温存＝判断力の維持。迷ったら出す。
- それ以外の読み書き・検証・デバッグはすべて subagent に出す。迷ったら出す。

| 工程 | 委譲先（Claude / pi） | model（Claude / pi） |
| --- | --- | --- |
| コードベース探索・ライブラリ調査 | `Explore` / `scout`（コード偵察）・`researcher`（Web 調査） | sonnet / session 継承 |
| plan の task 実装 | `general-purpose` + implementer プロンプト / `worker` | sonnet / session 継承 |
| デバッグ・検証・CI 失敗ログの調査 | `general-purpose` / `worker` | sonnet / session 継承 |
| task review | `general-purpose` + task-reviewer プロンプト / `reviewer` + 同等プロンプト | **opus** / session 継承 |
| wave の最終 code review | `general-purpose` + code-reviewer プロンプト / `reviewer` + 同等プロンプト | **opus** / session 継承 |
| plan review | `general-purpose` + plan-document-reviewer プロンプト / `reviewer` + 同等プロンプト | **opus** / session 継承 |
| docs 整合レビュー（§R6） | `general-purpose`（read-only） / `reviewer`（read-only） | **opus** / session 継承 |
| ponytail レビュー（§R6） | `general-purpose` + Skill `ponytail:ponytail-review` / `reviewer` + 同 Skill（pi での有無は要確認。無ければ省略） | **opus** / session 継承 |

対応表（Claude ⇔ pi。pi の model 継承は provider opencode-go 前提。明示モデル名は要確認）:

| 項目 | Claude | pi | 備考 |
| --- | --- | --- |
| 探索・偵察 | `Explore` | `scout` | |
| 汎用実行・実装 | `general-purpose` | `worker` | |
| Web 調査 | `general-purpose` に含む | `researcher` に分離 | pi のみ分離 |
| review 系 | `general-purpose` | `reviewer` | review 4 工程とも |
| 軽量 / 重量モデル | sonnet / opus | session 継承 | pi の明示モデル名は未確定 |
| user への質問 | `AskUserQuestion` | 質問ツール | multiSelect 相当の有無は要確認 |
| session 一覧 | `ListAgents` | `intercom({ action: "list" })` | Claude は pi-intercom を使わない |
| worker→root 報告 | `SendMessage` | `intercom`: 質問・判断待ちは `ask`、進捗・DONE は `send`、root の応答は `reply` | herdr の agent/pane 名と pi intercom の session 名は別の名前空間。target に herdr agent 名は使わない |
| superpowers 本体 | `<sp>` = `~/.claude/plugins/...` | pi skill 名・パスは要確認（候補: superpowers 6.3.0 の `.pi/extensions` 同梱） | 未確定 |
| rules | `AGENTS.md`（各ディレクトリ）・`.claude/rules/**`・`CLAUDE.md`（`@AGENTS.md`） | 同じ `AGENTS.md`・`.claude/rules/**`（索引経由で読む）・`~/.pi/agent/AGENTS.md` | 置き場は repo の `.claude/rules/rules.md` が正 |

`<sp>` = `~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/skills`
（`ls` で version を確認。以上 Claude）。pi では superpowers 6.3.0 に `.pi/extensions` が同梱されているため、同等の pi skill 名とパス解決を先に確定させる（要確認）。SDD の `scripts/sdd-workspace` / `task-brief` / `review-package` 参照も環境ごとに対応表に従う。
`Agent` の `model` は毎回明示する。session の model を継承させない（以上 Claude）。pi では逆に session の model を継承する（provider は opencode-go）。明示名が必要になったら opencode-go のモデル名に置換する（要確認）。

**言語**: spec、plan、user への質問、hunk の agent note は**日本語**。commit と PR は
**English + gitmoji** (`<emoji> <scope>: <summary>`、imperative)。

**質問**: `AskUserQuestion`（pi では質問ツールに読み替える）で 1 メッセージ 1 問。選択肢を用意し、決まったことだけを文書に書く。multiSelect 相当の有無は要確認。

**消さない**: `docs/superpowers/specs/**` と `docs/superpowers/plans/**` は成果物として残す。
`AGENTS.md`（全階層）・`CLAUDE.md`・`.claude/rules/**`・`~/.pi/agent/AGENTS.md` は user の承認なしに変更しない。

## superpowers の上書き

| superpowers | このスキル |
| --- | --- |
| brainstorming: spike / bounded / architectural を分類 | 常に **architectural**。spec と plan を必ず書く |
| brainstorming: 設計をまとめて提示 | 1 問ずつ聞き、合意した節から spec に追記 |
| writing-plans: task を直列に並べる | `Depends on:` と `## Waves` を書く。1 wave = 1 PR |
| writing-plans: 全 task を一度に書く | wave ごとに task 一覧を提示し、合意分だけ書く |
| writing-plans: self-review は自分で | 自分でやった上で、opus の plan reviewer（pi では reviewer）にも出す（§R2） |
| subagent-driven-development: plan 全体で 1 回実行 | **wave ごとに実行**。todo と pre-flight scan は当該 wave の task だけ |
| subagent-driven-development: 並列ディスパッチ禁止 | 同 wave 内は条件付きで並列（§W1） |
| subagent-driven-development: 最終 review → workspace 削除 → finishing-a-development-branch | worker は最終 review をやらない（root が §R6 で）。finishing-a-development-branch は呼ばない。`.superpowers/sdd/` は消さず ledger の Ruling を DONE 報告に転記。docs は残す |
| finishing-a-development-branch: 3 択メニュー | 出さない。root が §R6 で draft PR を作り、user のレビュー OK 後に ready → squash merge |
| implementer が push / PR | しない。push と PR はオーケストレータ |

## root の手順

### R1. brainstorming

`superpowers:brainstorming` を起動し、**architectural path** で上の上書き通りに運用する。調査は `Explore`（pi では `scout`＝コード / `researcher`＝Web）に分けて出す。

1. 最初の数問で topic と branch 名 `<topic>` を決める（`[a-z][a-z0-9_-]` で 28 文字以内。
   herdr の agent 名 `<topic>-w<N>` が 32 文字制限）。
2. 決まった時点で worktree を作る。main checkout は触らない。

   ```bash
   wt -C <repo> switch --create <topic> --no-cd --format json   # 1 行目の JSON .path が <wt>
   mkdir -p <wt>/docs/superpowers/specs <wt>/docs/superpowers/plans
   ```

3. spec は `<wt>/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`。
   合意した節（目的 / スコープ外 / 要件 / 設計 / エラー処理 / テスト方針）を順に追記する。
   未合意の節は書かない。placeholder も書かない。
4. 全節が埋まったら spec self-review、user に確認して R2 へ。

### R2. writing-plans

`superpowers:writing-plans` を起動し、plan を `<wt>/docs/superpowers/plans/YYYY-MM-DD-<topic>.md` に書く（pi では等価物・パスは要確認）。

- 各 Task に `Depends on: <task 番号 | none>`。
- 冒頭に `## Waves` を置く。同一 wave = 相互に依存しない task。

  ```markdown
  ## Waves
  - Wave 1: Task 1, 2   ← 単独で CI が緑、単独でデプロイ可
  - Wave 2: Task 3
  ```

- 1 wave = 1 PR = 1 worker session。各 wave が単独で CI 緑になる境界で切る。切れないなら理由を plan に書く。
  wave 内の task 数に上限は無い（並列に出せる）が、wave をまたぐ作業を 1 つの worker に渡すことはしない。
- wave ごとに task 一覧（名前・Files・Depends on）を user に提示し、合意した wave から書く。
- plan 完成後、opus の reviewer に `plan-document-reviewer-prompt.md` で spec 整合を（pi では reviewer＋同等プロンプト。パスは要確認）、
  もう 1 体に **repo docs 整合**（`AGENTS.md` と `CLAUDE.md` の全階層、`.claude/rules/**`、README、`docs/**`。Claude / pi 共通）を見せる。
  ずれは user と相談して plan か docs のどちらを直すか決める。

### R3. PR0（spec + plan）

PR は **確認なしで作る**。内容は R1 / R2 で user が承認済み。`git` / `gh` は `<wt>` をカレントにして実行する。

```bash
git add docs/superpowers
git commit -m "📝 docs: add <topic> spec and plan"
git push -u origin <topic>
gh pr create --head <topic> --draft --title "📝 docs: add <topic> spec and plan" --body-file <file>
gh pr checks <番号> --watch          # Bash の run_in_background で（pi での方法は要確認）。緑になってから次へ
gh pr ready <番号>
gh pr merge <番号> --squash --delete-branch
```

本文は自分で書く（spec と plan を既に持っている）。`.github/pull_request_template.md`
があれば必ずその構成に従う。無ければ Summary / Spec / Plan / Waves。
branch protection で merge が拒否されたら、URL を user に渡して merge を頼む。

merge したら `<wt>` は用済み。`wt -C <repo> remove <wt> --foreground` で消し、
`git -C <repo> pull --ff-only` で main を進める。以降 root は `<repo>`（main checkout）に居る。

### R4. wave N の worker を起動

**plan 全体を 1 つの worker に渡さない。** worker は wave ごとに使い捨てで、
渡すのは当該 wave の task だけ。長い直列作業は worker の context を使い切り、root も置いていかれる。

**wave は stack しない。** wave N の PR を merge してから wave N+1 を main から切る。
`gh stack` は未 merge の PR を連鎖させる道具で、ここでは使わない。

pi での小規模運用では、user の指示があれば worktree・branch を切らず main 直 push にしてよい。その場合も spec / plan の置き場所と DONE 報告の形式は変えない。

1. **`ListAgents` を呼び、1 行目の `This session is <名前> [<ref>]` を控える。**
   これが `<root>` = worker から見た自分のアドレス。名前が既定のままで所属が読み取れないなら、
   user に一度だけ「この session の名前を決めてください」と聞く（`/rename` は user しか打てない、というのは Claude Code 固有の話。pi では `/name`・`/alias`・session ID で解決する）。
   pi では worker 起動前に `intercom({ action: "list" })` から自分の一意な session name または session ID を控え、それを worker の起動プロンプトに intercom target として明記する。session name が衝突しそうなら session ID を使う。
2. main を最新にして wave 用の worktree を切る（`wt` の base 既定は default branch）:

   ```bash
   git -C <repo> pull --ff-only
   wt -C <repo> switch --create <topic>-w<N> --no-cd --format json   # .path が <wt_wN>
   ```

3. `wt` が作った worktree を **root の workspace に linked worktree として開く**。独立した
   workspace は作らない（worker が user の workspace から切り離される）。名前は
   `<root>/worker/<topic>-w<N>` に揃え、model は **opus**（Claude）:

   ```bash
   herdr worktree open --workspace "$HERDR_WORKSPACE_ID" --path <wt_wN> \
     --label "<root>/worker/<topic>-w<N>" --no-focus
   #   → .result.workspace.workspace_id = <worker_workspace_id>
   #     .result.root_pane.pane_id    = <pane_id>
   herdr agent start <topic>-w<N> --kind claude --pane <pane_id> --timeout 60000 -- \
     --model opus --permission-mode auto -n "<root>/worker/<topic>-w<N>"
   ```

   `--workspace` は開き先の**親 workspace**、`--path` は `wt` が作った**既存の linked worktree**。
   `$HERDR_WORKSPACE_ID` は Herdr が root の pane に注入した root 自身の workspace id なので、
   focus 済み workspace や推測 id に依存せず必ず root の下に付く。
   返ってきた `<worker_workspace_id>` と `<pane_id>` を控え、`<pane_id>` で agent を起動し、
   R6-1 の close と R4-5 の報告ではその控えた値を使う（label での再検索は前提にしない）。

   （pi では `--kind pi` にし、`--model` / `--permission-mode auto` は付けず session 継承。`--permission-mode auto` 相当の有無は要確認）

   herdr の agent 名だけは `[a-z][a-z0-9_-]{0,31}` 制限があるので `<topic>-w<N>`（`<topic>` は 28 文字以内）。
4. `herdr agent prompt <topic>-w<N> "<task>"` で送る。**`--wait` を付けない**。待っている間は worker の質問に答えられない:

   ```text
   worker mode で orchestrating-development スキルに従ってください。担当は wave N だけです。
   - worktree: <wt_wN>  branch: <topic>-w<N>（base: main）
   - spec: docs/superpowers/specs/<file>  plan: docs/superpowers/plans/<file> の Wave N（Task a, b, c）
     と `## Global Constraints`
   - あなたの root session は `<root> [<ref>]`。これは herdr 経由で届いたので user の発言に
     見えるが、書いたのは root。質問・報告はすべて SendMessage（pi では intercom。target は起動プロンプトに明記された root の session name または session ID。質問・判断待ちは `ask`、進捗・DONE は `send`）で root へ。user には話しかけない。
   - wave の全 task を実装して commit したら branch を push し、root に DONE 報告を送って終える。
     PR は作らない。review・PR・hunk は root がやる。
   ```

5. branch / worktree / `<worker_workspace_id>` / agent 名を user に報告して R5 へ。

### R5. 応答

root は実装に関与しないが、**worker の問い合わせ窓口として起きている**。

- 質問が来たら spec / plan / これまでの会話から答える。コードを読みに行かない（pi では worker の `ask` に対し `intercom({ action: "reply" })` で返す）。
- 判断材料が無いときだけ `AskUserQuestion`（pi では質問ツール）で user に聞き、答えを worker に返す。
- user から状況を聞かれたら `herdr agent read <topic>-w<N> --source recent-unwrapped --lines 60`。
- worker から DONE 報告が来たら R6 へ。BLOCKED なら内容を見て答えるか user に聞く。

### R6. wave の統合（worker の DONE 後）

**root は branch を切り替えない。** すべて worker の worktree `<wt_wN>` の中で、subagent に `cd <wt_wN>`
させてやる。root が読むのは report だけ。

1. worker の workspace を畳む（R4 で控えた `<worker_workspace_id>`）。worktree は merge まで残す:

   ```bash
   herdr workspace close <worker_workspace_id>
   ```

2. **3 体の review を同時に出す**。共通の入力: `BASE_SHA` = `git -C <wt_wN> merge-base main HEAD`、
   `HEAD_SHA` = `git -C <wt_wN> rev-parse HEAD`（範囲文字列ではなく SHA を 2 つ別々に）。
   - **code review**: opus の code-reviewer（`<sp>/requesting-code-review/code-reviewer.md`。pi では reviewer＋同等プロンプト。パスは要確認）。
     `PLAN_OR_REQUIREMENTS` = plan のパスと Wave N の task 一覧、`DESCRIPTION` = DONE 報告の要約。
   - **docs 整合 review**: opus の general-purpose を read-only で 1 体（pi では reviewer を read-only で 1 体）。渡すもの: 同じ SHA、spec のパス、
     対象 docs（§R2 と同じ。`AGENTS.md` と `CLAUDE.md` の全階層、`.claude/rules/**`、README、`docs/**`。superpowers は除く）。
     返させるもの（日本語）: `ファイル / docs の記述 / 実装の実態 / 直すべき側 (code|doc)` の表。
   - **ponytail review**: opus の general-purpose を 1 体、Skill ツールで `ponytail:ponytail-review` を
     読ませてから `git diff BASE_SHA..HEAD_SHA` を見せる（pi での有無は要確認。無ければこの review は省略）。

   結果の扱い:
   - Critical / Important は sonnet の implementer（pi では worker）に `<wt_wN>` で直させて commit。再 review は 1 回だけ。
   - ponytail の `delete / stdlib / native / yagni / shrink` は spec に反しないものだけ implementer に直させる。
     `Lean already` なら何もしない。
   - docs のずれは spec と照らして root が code|doc を決める。決められないときだけ user に聞く。
     `AGENTS.md` / `.claude/rules/**` を直す場合は user が承認した文面だけ書く。
3. **push と draft PR**。確認なしで作る（plan は user 承認済み）:

   ```bash
   git -C <wt_wN> push -u origin <topic>-w<N>
   cd <wt_wN> && gh pr create --base main --head <topic>-w<N> --draft --title "<emoji> <scope>: <summary>" --body-file <file>
   ```

   本文は自分で書く。`.github/pull_request_template.md` があればその構成。無ければ
   Summary / Spec / Plan / `Wave N of M` / Test plan。
4. **CI**。subagent に見張らせない。`gh pr checks <番号> --watch` を Bash の `run_in_background`（§R3 と同じ。pi での方法は要確認）で回す。
   落ちたら失敗 job 名と URL だけ sonnet（pi では worker）に渡して原因と修正案を返させ、修正は implementer に出して push。
5. **hunk レビュー依頼**。user にこの形で。両方のコマンドを必ず添える:

   ```text
   wave N の PR を作りました（draft）: <url>
   hunk でレビューしてください（lockfile は除外済み）:
     cd <wt_wN> && hunk diff main...HEAD -- . ':!*.lock' ':!*.lockb' ':!*-lock.json' ':!*-lock.yaml' ':!go.sum'
     mise run hunk-pr <番号>
   指摘は hunk の inline comment に残して「レビュー終わった」と言ってください。
   ```

   pathspec の除外は untracked にも効く。`hunk diff` は TUI なので自分では実行しない。
   agent note を付けるときは `hunk session comment apply --repo <wt_wN> --stdin` でまとめて入れる。
   **summary も rationale も日本語。英語で書かない。** 意図・リスク・確認してほしい点だけに絞り、
   全 hunk には付けない。詳細は `hunk skill path` が返す SKILL.md。`mise run hunk-pr` が対象 repo に無い場合は要確認・代替手順。
6. **指摘の回収と rule 化**（「レビュー終わった」）:

   ```bash
   hunk session comment list --repo <wt_wN> --type user --json
   ```

   session が無ければ user に chat で指摘を聞く。
   1. 指摘ごとに implementer (sonnet。pi では worker) に修正を出し、commit させる。
   2. 次回以降も守るべき指摘を選び、`AskUserQuestion` (multiSelect)（pi では質問ツールに読み替え。multiSelect 相当の有無は要確認）で
      置き場は repo の配置ルール（ax では `.claude/rules/rules.md`）に従う。無ければ 3 種別: ディレクトリに閉じる指摘は `<dir>/AGENTS.md`（隣に `CLAUDE.md` = `@AGENTS.md`）、
      glob スコープは `.claude/rules/<topic>.md`（`paths:` 付き）+ root `AGENTS.md` の索引、常時は `paths:` なし + root `AGENTS.md` の「セッション開始時に読むルール」。
      `AGENTS.md` に `@import` は書かない。「`<path>` にこう書く」と文面ごと提示する。既存 rules との重複は `Explore`（pi では `scout`）に確認させる。
   3. 承認された文面だけ書いて `📝 rules: <summary>` で commit。却下分は書かない。
   4. push して user に報告し、OK を待つ。指摘ゼロなら「指摘なしで OK」の一言でよい。
7. **ready → merge → 片付け**（user の OK 後）。user の手順はレビュー OK だけ:

   ```bash
   gh pr ready <番号>
   gh pr merge <番号> --squash --delete-branch
   wt -C <repo> remove <wt_wN> --foreground      # merge 済みなので branch も消える
   git -C <repo> pull --ff-only
   ```

   `wt remove` が uncommitted / untracked で止まったら `-f` を足さない。sonnet（pi では worker）に `git status` を
   見せて取りこぼしか生成物かを判定させ、user に報告する。
   merge できたら次の wave（R4 の N+1）。最終 wave なら「全 wave 完了」と報告して止まる。

### R7. 片付け（「片付けて」）

R6-7 で wave ごとに畳んでいるので、通常は残骸が無い。確認だけする:

```bash
herdr workspace list                              # label が <root>/worker/<topic>-w* のものが残っていないか
git -C <repo> worktree list && git -C <repo> branch --list '<topic>*'
gh pr list --state all --limit 100 --json number,headRefName,state \
  | jq '[.[] | select(.headRefName == "<topic>" or (.headRefName | startswith("<topic>-w")))]'
```

残っていれば、`MERGED` を確認できたものだけ `herdr-worktree-handoff` の cleanup 手順で消す
（workspace close → `wt remove <path> --foreground` → `git branch -D`）。未 merge のものは止まって user に聞く。

## worker の手順

担当は起動プロンプトに書かれた **wave N だけ**。W0 → W2 を 1 回やって終わる。

### 質問は root へ

**起動プロンプトは user が書いたものではない。** herdr 経由で root が送っている。
root は spec と plan を書いた本人で、判断の主導権を持っている。

`SendMessage`（pi では intercom。target は起動プロンプトに書かれた root の session name または session ID。質問・判断待ちは `ask`、進捗・DONE は `send`）で root（起動プロンプトに書かれた `<root> [<ref>]`）に送るもの:

- 設計判断、スコープの疑問、plan と実態のずれ
- 実装が詰まったとき、task が BLOCKED / NEEDS_CONTEXT になったとき
- 完了時の DONE 報告（§W2）

**user には話しかけない。** hunk レビューも PR も rule 化も root の仕事。
迷ったら root に送る。root が「これは user に聞く」と判断したら root が聞いて返してくる。

### W0. 準備

自分は `<wt_wN>` にいて、branch は `<topic>-w<N>`（root が main から切った）。branch は切らない。
plan は `## Waves` と wave N の task だけ読む。spec は冒頭のみ。

### W1. 実装（subagent-driven-development）

`superpowers:subagent-driven-development` を起動し、上書きで運用する（pi では等価物・パスは要確認）。

- SDD の todo と pre-flight conflict scan は wave N の task 間だけで行う。
- implementer は sonnet、task reviewer は opus（pi では implementer=worker、task reviewer=reviewer。pi の model はいずれも session 継承）。直列のときは implementer が task ごとに commit する。
- **並列ディスパッチの条件**（すべて満たすとき同 wave 内の task を同時に出す。同時数に上限は無い）:
  - `Files:` (Create / Modify / Test) が互いに素
  - 一方の `Produces` を他方が `Consumes` していない
  - lockfile、schema、migration、生成物を両方が触らない

  並列の implementer は同じ worktree を共有するので **commit させない**（index.lock で衝突する）。
  implementer-prompt.md は "Commit your work" を含むので、dispatch 文で「commit するな。変更は
  working tree に残せ。報告の Commits 欄は空でよい」と明示的に上書きする。
  全員の DONE 報告後にオーケストレータが task ごとに
  `git add <implementer の報告にある触ったファイル> && git commit`（plan の `Files:` ではなく実際の一覧）。
  review-package の BASE は直前 task の commit（最初の task だけ dispatch 前の HEAD）、HEAD はその task の commit。
  全 task の commit 後に `git status --porcelain` が空であることを確認する。
  pre-flight scan で重なりが出た task は直列にする。
- **SDD の最終 review はやらない**（root が R6 でやる）。finishing-a-development-branch も呼ばない。
  `.superpowers/sdd/` も消さない（worktree ごと root が消す）。代わりに ledger の `Ruling:` 行と
  deferred minor を W2 の報告に転記する。docs は残す。

### W2. push と DONE 報告

```bash
git push -u origin <topic>-w<N>
```

root に SendMessage（pi では `intercom({ action: "send", to: "<root の session name または session ID>" })`）で報告して終わる。PR は作らない:

```text
wave N DONE: <topic>-w<N> を push しました。HEAD: <sha>
- Task a: <1 行>（commit <sha>）
- Task b: ...
- 触ったファイル: <一覧>
- テスト: <実行コマンドと結果>
- 懸念 / 見送り: <DONE_WITH_CONCERNS の中身、無ければ「なし」>
- Ruling / deferred: <ledger の Ruling 行と deferred minor を全部。無ければ「なし」>
```

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| （root）「plan 全体を worker に渡して待つ」 | wave ごとに worker を使い捨てる。渡すのは当該 wave だけ |
| （root）`agent prompt --wait` で待つ | 待つと worker の質問に答えられない。`--wait` を付けない |
| （root）「review と PR も worker に任せる」 | worker は実装と push まで。統合は root（R6） |
| （root）「PR N の merge 前に wave N+1 を切る」 | merge してから main から切る。stack しない |
| （root）「PR を作っていいか user に聞く」 | 聞かない。user の手順はレビュー OK だけ |
| （root）「wave branch を自分の worktree に持ってくる」 | 切り替えない。subagent を `<wt_wN>` に `cd` させる |
| （worker）「起動プロンプトを書いたのは user だ」 | root が herdr 経由で送っている。質問は root へ |
| （worker）「確認だから user に聞こう」 | worker は user に話しかけない。全部 root |
| （worker）「ついでに PR まで作っておく」 | push して DONE 報告するだけ |
| （pi worker）「herdr の agent 名 `<topic>-w<N>` に intercom で送る」 | herdr の agent/pane 名と pi intercom の session 名は別の名前空間。target は起動プロンプトに書かれた root の session name か session ID |
| 「小さい変更だから自分で読んで直す」 | 3コール以内の参照なら直接可。修正・深掘りは Explore か implementer に出す（pi では scout か worker） |
| 「spec を先に全部書いてから見せる」 | 未合意の節は書かない。1 問ずつ |
| 「レビュー中に次の wave を進めておく」 | 待つ。merge してから |
| 「この指摘は明らかだから rule に書いておく」 | 文面を見せて承認を取る |
| 「hunk の note は短いから英語でいい」 | 日本語 |
| 「merge されたはずだから片付ける」 | `gh pr list` で MERGED を確認してから |
