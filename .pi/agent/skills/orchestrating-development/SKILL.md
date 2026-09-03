---
name: orchestrating-development
description: Use when the user asks to build, implement, refactor, or fix something in a git repo that needs a spec and plan before code — 「〜を実装して」「〜機能を作りたい」「issue #N をやって」「リファクタして」, "build X", "implement this". Also use when a session was started as a worker for a plan (「worker mode で」), when the user reports a hunk review is done (「レビュー終わった」), or asks to clean up a finished handoff (「片付けて」). Not for questions, spikes, or one-line fixes with no plan.
---

# Orchestrating development

superpowers (brainstorming → writing-plans → subagent-driven-development) を土台に、
**spec / plan を root session が書き、実装は herdr の worker session に委譲し、
user は hunk で PR をレビューする**流れに固定する。

superpowers 本文と矛盾する箇所は**このスキルが優先**する
(`superpowers:using-superpowers` の "User instructions take precedence over skills" に依拠)。

## モード判定

| 状況 | モード |
| --- | --- |
| user が機能実装・修正を依頼した | **root** |
| 起動プロンプトに「worker mode で orchestrating-development」とある | **worker** |
| user が「レビュー終わった」と言った | worker の §W5 へ |
| user が「片付けて」と言った | root の §R6 へ |

## 共通ポリシー

**オーケストレータはコードを読まない・書かない。** 高いのは読むことであって書くことではない。

- 自分で読んでよいもの: spec、plan、subagent の報告、hunk のコメント、`.github/pull_request_template.md`、`.claude/rules/**` の見出し。
- 自分で書いてよいもの: spec、plan、commit / PR のタイトルと本文、`.claude/rules/**`（user 承認後）。
- それ以外の読み書き・検証・デバッグはすべて subagent に出す。迷ったら出す。

| 工程 | 委譲先 (`subagent_type` + prompt) | model |
| --- | --- | --- |
| コードベース探索・ライブラリ調査 | `Explore` | sonnet |
| plan の task 実装 | `general-purpose` + `<sp>/subagent-driven-development/implementer-prompt.md` | sonnet |
| デバッグ・検証・CI 失敗ログの調査 | `general-purpose` | sonnet |
| task review | `general-purpose` + `<sp>/subagent-driven-development/task-reviewer-prompt.md` | **opus** |
| wave の最終 code review | `general-purpose` + `<sp>/requesting-code-review/code-reviewer.md` | **opus** |
| plan review | `general-purpose` + `<sp>/writing-plans/plan-document-reviewer-prompt.md` | **opus** |
| docs 整合レビュー（§W2） | `general-purpose` | **opus** |

`<sp>` = `~/.claude/plugins/cache/claude-plugins-official/superpowers/<version>/skills`
（`ls` で version を確認）。SDD の `scripts/sdd-workspace` / `task-brief` / `review-package` も同じ場所。
`Agent` の `model` は毎回明示する。session の model を継承させない。

**言語**: spec、plan、user への質問、hunk の agent note は**日本語**。commit と PR は
**English + gitmoji** (`<emoji> <scope>: <summary>`、imperative)。

**質問**: `AskUserQuestion` で 1 メッセージ 1 問。選択肢を用意し、決まったことだけを文書に書く。

**消さない**: `docs/superpowers/specs/**` と `docs/superpowers/plans/**` は成果物として残す。
`.claude/rules/**` と `CLAUDE.md` は user の承認なしに変更しない。

## superpowers の上書き

| superpowers | このスキル |
| --- | --- |
| brainstorming: spike / bounded / architectural を分類 | 常に **architectural**。spec と plan を必ず書く |
| brainstorming: 設計をまとめて提示 | 1 問ずつ聞き、合意した節から spec に追記 |
| writing-plans: task を直列に並べる | `Depends on:` と `## Waves` を書く。1 wave = 1 PR |
| writing-plans: 全 task を一度に書く | wave ごとに task 一覧を提示し、合意分だけ書く |
| writing-plans: self-review は自分で | 自分でやった上で、opus の plan reviewer も出す（§R2） |
| subagent-driven-development: plan 全体で 1 回実行 | **wave ごとに実行**。todo と pre-flight scan は当該 wave の task だけ |
| subagent-driven-development: 並列ディスパッチ禁止 | 同 wave 内は条件付きで並列（§W1） |
| subagent-driven-development: Finish で workspace 削除 → finishing-a-development-branch | **最終 wave まで workspace を残す**。finishing-a-development-branch は呼ばない。削除は `.superpowers/sdd/<plan 名>/` のみ、docs は残す |
| finishing-a-development-branch: 3 択メニュー | 出さない。1 行確認して自分で PR を作る |
| implementer が push / PR | しない。push と PR はオーケストレータ |

## root の手順

### R1. brainstorming

`superpowers:brainstorming` を起動し、**architectural path** で上の上書き通りに運用する。調査は `Explore` に出す。

1. 最初の数問で topic と branch 名 `<topic>` を決める（`[a-z][a-z0-9_-]{0,31}`、herdr の agent 名になる）。
2. 決まった時点で worktree を作る。main checkout は触らない。

   ```bash
   wt -C <repo> switch --create <topic> --no-cd --format json   # 1 行目の JSON .path が <wt>
   mkdir -p <wt>/docs/superpowers/specs <wt>/docs/superpowers/plans
   ```

3. spec は `<wt>/docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`。
   合意した節（目的 / スコープ外 / 要件 / 設計 / エラー処理 / テスト方針）を順に追記する。
   未合意の節は書かない。placeholder も書かない。
   **節の案は chat 本文に書かない。** chat の長文は `summarized` で省略されて user が読めない。
   `AskUserQuestion` の option `preview` に本文ごと入れて提示し、OK が出た本文をそのまま spec に書く。
4. 全節が埋まったら spec self-review、user に確認して R2 へ。

### R2. writing-plans

`superpowers:writing-plans` を起動し、plan を `<wt>/docs/superpowers/plans/YYYY-MM-DD-<topic>.md` に書く。

- 各 Task に `Depends on: <task 番号 | none>`。
- 冒頭に `## Waves` を置く。同一 wave = 相互に依存しない task。

  ```markdown
  ## Waves
  - Wave 1: Task 1, 2   ← 単独で CI が緑、単独でデプロイ可
  - Wave 2: Task 3
  ```

- 1 wave = 1 PR。各 wave が単独で CI 緑になる境界で切る。切れないなら理由を plan に書く。
- wave ごとに task 一覧（名前・Files・Depends on）を user に提示し、合意した wave から書く。
  一覧も chat 本文ではなく `AskUserQuestion` の `preview` に入れる（R1 と同じ理由）。
- plan 完成後、opus の reviewer に `plan-document-reviewer-prompt.md` で spec 整合を、
  もう 1 体に **repo docs 整合**（CLAUDE.md、`.claude/rules/**`、README、`docs/**`）を見せる。
  ずれは user と相談して plan か docs のどちらを直すか決める。

### R3. PR0（spec + plan）

以降の `git` / `gh` はすべて `<wt>` をカレントにして実行する（`gh` は cwd から repo を解決する）。

```bash
git add docs/superpowers
git commit -m "📝 docs: add <topic> spec and plan"
```

「PR0 (spec/plan) を push して draft PR を作ります。いいですか?」と 1 行確認してから:

```bash
git push -u origin <topic>
gh pr create --head <topic> --draft --title "📝 docs: add <topic> spec and plan" --body-file <file>
```

本文は自分で書く（spec と plan を既に持っている）。`.github/pull_request_template.md`
があれば必ずその構成に従う。無ければ Summary / Spec / Plan / Waves。

### R4. handoff

`herdr-worktree-handoff` に従う。worktree は R1 で作ったので step 1 を飛ばし、
workspace 作成から始める。worker の model は **opus** に固定する:

```bash
herdr agent start <topic> --kind claude --pane <pane_id> --timeout 60000 -- --model opus --permission-mode auto -n <topic>
```

task はこの文面:

```text
worker mode で orchestrating-development スキルに従ってください。
- worktree: <wt>  branch: <topic>
- spec: docs/superpowers/specs/<file>  plan: docs/superpowers/plans/<file>
- PR0: <url>（spec/plan、draft）。wave PR はこの branch を base にスタックする。
- wave 1 から順に。各 wave の PR を作ったら user に hunk レビューを依頼し、
  「レビュー終わった」を待ってから次の wave へ。
- 全 wave が終わったら 1 行サマリで終える。
```

`agent prompt --wait` が何を返しても、その状態と branch / worktree / workspace id /
agent 名 / PR0 の URL を報告して止まる。以降 user は Herdr から worker と直接やり取りする。

### R5. 待機

root は実装に関与しない。user から状況を聞かれたら `herdr agent read <topic> --source recent-unwrapped --lines 60` で答える。

### R6. 片付け（「片付けて」）

全 PR が merge 済みか先に確認する。1 つでも未 merge なら止まって報告する。

```bash
gh pr list --repo <owner/repo> --state all --limit 100 --json number,headRefName,state \
  | jq '[.[] | select(.headRefName == "<topic>" or (.headRefName | startswith("<topic>-w")))]'
```

`<owner/repo>` は `<wt>` で `gh repo view --json nameWithOwner -q .nameWithOwner`。
全部 `MERGED` なら、`herdr-worktree-handoff` の cleanup 手順で workspace close → worktree 削除:

```bash
wt -C <repo> remove <wt> --foreground        # branch 名ではなく worktree のパスで指定
git -C <repo> branch -D <topic> <topic>-w1 <topic>-w2 ...   # squash merge だと -d は通らない。MERGED 確認済みなので -D
git -C <repo> fetch --prune
git -C <repo> worktree list && git -C <repo> branch          # 消えたことを確認
```

`wt remove` が uncommitted changes で止まったら `-f` を足さずに user に聞く。

## worker の手順

wave ごとに W1 → W5 を繰り返す。**次の wave は user の「レビュー終わった」と OK のあと。**

### W0. 準備

plan は `## Waves` と当該 wave の task だけ読む。spec は冒頭のみ。
`<前の branch>` = wave 1 では `<topic>`、wave N では `<topic>-w<N-1>`。以降の `<前の branch>` はすべてこれ。

```bash
git switch -c <topic>-w<N> <前の branch>   # 同じ worktree で。新しい worktree は作らない
```

### W1. 実装（subagent-driven-development）

`superpowers:subagent-driven-development` を起動し、上書きで運用する。

- SDD の todo と pre-flight conflict scan は当該 wave の task 間だけで行う。
- implementer は sonnet、task reviewer は opus。直列のときは implementer が task ごとに commit する。
- **並列ディスパッチの条件**（すべて満たすとき同 wave 内の task を同時に出す）:
  - `Files:` (Create / Modify / Test) が互いに素
  - 一方の `Produces` を他方が `Consumes` していない
  - lockfile、schema、migration、生成物を両方が触らない

  並列の implementer は同じ worktree を共有するので **commit させない**（index.lock で衝突する）。
  全員の DONE 報告後にオーケストレータが task ごとに `git add <その task の Files> && git commit`
  し、各 commit の SHA を review-package の BASE / HEAD に使う。
  pre-flight scan で重なりが出た task は直列にする。
- wave の全 task 後、`review-package <plan> <前の branch> HEAD` で最終 review を opus の code-reviewer に出す。
  workspace は消さない。finishing-a-development-branch は呼ばない。

### W2. docs 整合レビュー

opus の general-purpose を read-only で 1 体出す。渡すもの: diff 範囲 (`<前の branch>...HEAD`)、
spec のパス、対象 docs（CLAUDE.md、`.claude/rules/**`、README、`docs/**` から superpowers を除く）。
返させるもの（日本語）: `ファイル / docs の記述 / 実装の実態 / 直すべき側 (code|doc)` の表。

ずれが 1 つでもあれば `AskUserQuestion` で code と docs のどちらを直すか user に聞く。
docs 側を直す場合も rules / CLAUDE.md は承認された文面だけ書く。

### W3. push と PR

「wave N の PR を push します（base: `<前の branch>`）。いいですか?」と 1 行確認してから:

```bash
git push -u origin <topic>-w<N>
gh pr create --base <前の branch> --head <topic>-w<N> --title "<emoji> <scope>: <summary>" --body-file <file>
```

本文は自分で書く。`.github/pull_request_template.md` があればその構成。無ければ
Summary / Spec / Plan / `Wave N of M` (stack 順) / Test plan。

CI は subagent に見張らせない。`gh pr checks <番号> --watch` を Bash の `run_in_background` で回す。
落ちたら失敗 job 名と URL だけ sonnet に渡して原因と修正案を返させ、修正は implementer に出す。

### W4. hunk レビュー依頼

user にこの形で依頼する。両方のコマンドを必ず添える:

```text
wave N の PR を作りました: <url>
hunk でレビューしてください（lockfile は除外済み）:
  cd <wt> && hunk diff <前の branch>...HEAD -- . ':!*.lock' ':!*.lockb' ':!*-lock.json' ':!*-lock.yaml' ':!go.sum'
  mise run hunk-pr <番号>
指摘は hunk の inline comment に残して「レビュー終わった」と言ってください。
```

pathspec の除外は untracked にも効く。`hunk diff` は TUI なので自分では実行しない。

agent note を付けるときは `hunk session comment apply --repo <wt> --stdin` でまとめて入れる。
**summary も rationale も日本語。英語で書かない。** 意図・リスク・確認してほしい点だけに絞り、
全 hunk には付けない。詳細は `hunk skill path` が返す SKILL.md。

### W5. 指摘の回収と rule 化（「レビュー終わった」）

```bash
hunk session comment list --repo <wt> --type user --json
```

session が無ければ user に chat で指摘を聞く。

1. 指摘ごとに implementer (sonnet) に修正を出し、commit させる。
2. 次回以降も守るべき指摘を選び、`AskUserQuestion` (multiSelect) で
   「`.claude/rules/<topic>.md` にこう書く」と文面ごと提示する。
   既存 rules との重複は `Explore` に確認させる。
3. 承認された文面だけ書いて `📝 rules: <summary>` で commit。却下分は書かない。
4. push して user に報告し、OK を待つ。OK が出たら次の wave (W0)。

最終 wave の OK が出たら `rm -rf <wt>/.superpowers/sdd/<plan 名>/` だけ消し、1 行サマリで終える。
docs は残す。片付けは root がやる。

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| 「小さい変更だから自分で読んで直す」 | 読むのが高い。Explore か implementer に出す |
| 「spec を先に全部書いてから見せる」 | 未合意の節は書かない。1 問ずつ |
| 「wave 1 つだけなら PR0 と一緒でいい」 | 例外を作らない。PR0 ← w1 で常にスタック |
| 「レビュー中に次の wave を進めておく」 | rebase 地獄になる。待つ |
| 「この指摘は明らかだから rule に書いておく」 | 文面を見せて承認を取る |
| 「hunk の note は短いから英語でいい」 | 日本語 |
| 「merge されたはずだから片付ける」 | `gh pr list` で MERGED を確認してから |
