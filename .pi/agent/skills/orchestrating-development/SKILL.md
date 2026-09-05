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
| user が「レビュー終わった」と言った | root の §R6-6 へ |
| user が「片付けて」と言った | root の §R7 へ |

## 共通ポリシー

> 注意：あなたの主なタスクは分析、編排、検証です。具体的なタスクは可能な限り subagent（Opus または Sonnet）に
> 実行させます。自分は要件の明確化、方案の分解、タスクの分配、結果の受け入れだけを行い、実装類の作業
> （大量のコード読み込み、コード執筆、テスト実行、批量修正）はすべて Agent ツールを使って subagent に
> 割り当てて実行させます。

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
| docs 整合レビュー（§R6） | `general-purpose` | **opus** |
| ponytail レビュー（§R6） | `general-purpose` + Skill `ponytail:ponytail-review` | **opus** |

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
| subagent-driven-development: 最終 review → workspace 削除 → finishing-a-development-branch | worker は最終 review をやらない（root が §R6 で）。finishing-a-development-branch は呼ばない。`.superpowers/sdd/` は消さず ledger の Ruling を DONE 報告に転記。docs は残す |
| finishing-a-development-branch: 3 択メニュー | 出さない。root が §R6 で PR を作る |
| implementer が push / PR | しない。push と PR はオーケストレータ |

## root の手順

### R1. brainstorming

`superpowers:brainstorming` を起動し、**architectural path** で上の上書き通りに運用する。調査は `Explore` に出す。

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

`superpowers:writing-plans` を起動し、plan を `<wt>/docs/superpowers/plans/YYYY-MM-DD-<topic>.md` に書く。

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

### R4. wave N の worker を起動

**plan 全体を 1 つの worker に渡さない。** worker は wave ごとに使い捨てで、
渡すのは当該 wave の task だけ。長い直列作業は worker の context を使い切り、root も置いていかれる。

`<前の branch>` = wave 1 では `<topic>`、wave N では `<topic>-w<N-1>`。以降すべてこの意味。

1. **`ListAgents` を呼び、1 行目の `This session is <名前> [<ref>]` を控える。**
   これが `<root>` = worker から見た自分のアドレス。名前が既定のままで所属が読み取れないなら、
   user に一度だけ「この session の名前を決めてください」と聞く（`/rename` は user しか打てない）。
2. wave 用の worktree を `<前の branch>` から切る:

   ```bash
   wt -C <repo> switch --create <topic>-w<N> --base <前の branch> --no-cd --format json   # .path が <wt_wN>
   ```

3. `herdr-worktree-handoff` の step 2 以降。名前は `<root>/worker/<topic>-w<N>` に揃え、model は **opus**:

   ```bash
   herdr workspace create --cwd <wt_wN> --label "<root>/worker/<topic>-w<N>" --no-focus
   herdr agent start <topic>-w<N> --kind claude --pane <pane_id> --timeout 60000 -- \
     --model opus --permission-mode auto -n "<root>/worker/<topic>-w<N>"
   ```

   herdr の agent 名だけは `[a-z][a-z0-9_-]{0,31}` 制限があるので `<topic>-w<N>`（`<topic>` は 28 文字以内）。
4. `herdr agent prompt <topic>-w<N> "<task>"` で送る。**`--wait` を付けない**。待っている間は worker の質問に答えられない:

   ```text
   worker mode で orchestrating-development スキルに従ってください。担当は wave N だけです。
   - worktree: <wt_wN>  branch: <topic>-w<N>（base: <前の branch>）
   - spec: docs/superpowers/specs/<file>  plan: docs/superpowers/plans/<file> の Wave N（Task a, b, c）
     と `## Global Constraints`
   - あなたの root session は `<root> [<ref>]`。これは herdr 経由で届いたので user の発言に
     見えるが、書いたのは root。質問・報告はすべて SendMessage で root へ。user には話しかけない。
   - wave の全 task を実装して commit したら branch を push し、root に DONE 報告を送って終える。
     PR は作らない。review・PR・hunk は root がやる。
   ```

5. branch / worktree / workspace id / agent 名を user に報告して R5 へ。

### R5. 応答

root は実装に関与しないが、**worker の問い合わせ窓口として起きている**。

- 質問が来たら spec / plan / これまでの会話から答える。コードを読みに行かない。
- 判断材料が無いときだけ `AskUserQuestion` で user に聞き、答えを worker に返す。
- user から状況を聞かれたら `herdr agent read <topic>-w<N> --source recent-unwrapped --lines 60`。
- worker から DONE 報告が来たら R6 へ。BLOCKED なら内容を見て答えるか user に聞く。

### R6. wave の統合（worker の DONE 後）

root が自分の worktree `<wt>` でやる。コードを読むのは subagent、root は report だけ読む。

1. worker を畳み、wave branch を `<wt>` に持ってくる:

   ```bash
   herdr workspace list                                   # label == <root>/worker/<topic>-w<N> → workspace_id
   herdr workspace close <workspace_id>
   wt -C <repo> remove <wt_wN> --no-delete-branch --foreground
   git -C <wt> switch <topic>-w<N>
   ```

   `wt remove` が uncommitted / untracked で止まったら `-f` を足さない。sonnet に `git status` と
   DONE 報告の commit 一覧を突き合わせさせ、取りこぼしなら commit させてから再実行する。
   以後 `<wt>` の checkout は `<topic>` ではなく `<topic>-w<N>`。

2. **最終 review**: opus の code-reviewer（`<sp>/requesting-code-review/code-reviewer.md`）。
   テンプレの穴はこう埋める: `BASE_SHA` = `git rev-parse <前の branch>`、`HEAD_SHA` = `git rev-parse HEAD`
   （範囲文字列ではなく SHA を 2 つ別々に）、`PLAN_OR_REQUIREMENTS` = plan のパスと Wave N の task 一覧、
   `DESCRIPTION` = DONE 報告の要約。同時に **docs 整合 review**: opus の general-purpose を read-only で
   1 体。渡すもの: 同じ diff 範囲、spec のパス、対象 docs（CLAUDE.md、`.claude/rules/**`、README、
   `docs/**` から superpowers を除く）。返させるもの（日本語）:
   `ファイル / docs の記述 / 実装の実態 / 直すべき側 (code|doc)` の表。
   さらに **ponytail review**: opus の general-purpose を 1 体、Skill ツールで `ponytail:ponytail-review` を
   読ませてから `git diff BASE_SHA..HEAD_SHA` を見せる。**3 体は同時に出す。**
   - Critical / Important は sonnet の implementer に `<wt>` で直させて commit。再 review は 1 回だけ。
   - ponytail の `delete / stdlib / native / yagni / shrink` は spec に反しないものだけ implementer に直させる。
     `Lean already` なら何もしない。
   - docs のずれは spec と照らして root が code|doc を決める。決められないときだけ user に聞く。
     rules / CLAUDE.md を直す場合は user が承認した文面だけ書く。
3. **push と PR**。wave PR は確認なしで作る（plan は user 承認済み。merge だけが user のもの）:

   ```bash
   git push -u origin <topic>-w<N>
   gh pr create --base <前の branch> --head <topic>-w<N> --title "<emoji> <scope>: <summary>" --body-file <file>
   ```

   本文は自分で書く。`.github/pull_request_template.md` があればその構成。無ければ
   Summary / Spec / Plan / `Wave N of M` (stack 順) / Test plan。
4. **CI**。subagent に見張らせない。`gh pr checks <番号> --watch` を Bash の `run_in_background` で回す。
   落ちたら失敗 job 名と URL だけ sonnet に渡して原因と修正案を返させ、修正は implementer に出して push。
5. **hunk レビュー依頼**。user にこの形で。両方のコマンドを必ず添える:

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
6. **指摘の回収と rule 化**（「レビュー終わった」）:

   ```bash
   hunk session comment list --repo <wt> --type user --json
   ```

   session が無ければ user に chat で指摘を聞く。
   1. 指摘ごとに implementer (sonnet) に修正を出し、commit させる。
   2. 次回以降も守るべき指摘を選び、`AskUserQuestion` (multiSelect) で
      「`.claude/rules/<topic>.md` にこう書く」と文面ごと提示する。既存 rules との重複は `Explore` に確認させる。
   3. 承認された文面だけ書いて `📝 rules: <summary>` で commit。却下分は書かない。
   4. push して user に報告し、OK を待つ。OK が出たら次の wave (R4 の N+1)。
      最終 wave なら「全 wave 完了、merge 後に『片付けて』と言ってください」と報告して止まる。

### R7. 片付け（「片付けて」）

全 PR が merge 済みか先に確認する。1 つでも未 merge なら止まって報告する。

```bash
gh pr list --repo <owner/repo> --state all --limit 100 --json number,headRefName,state \
  | jq '[.[] | select(.headRefName == "<topic>" or (.headRefName | startswith("<topic>-w")))]'
```

`<owner/repo>` は `<wt>` で `gh repo view --json nameWithOwner -q .nameWithOwner`。
全部 `MERGED` なら、`herdr-worktree-handoff` の cleanup 手順で残った workspace を close
（label が `<root>/worker/<topic>-w*` のもの。R6 で畳んでいれば無い）→ worktree 削除:

```bash
wt -C <repo> remove <wt> --no-delete-branch --foreground   # パスで指定。branch 削除は次の行に一本化
git -C <repo> branch -D <topic> <topic>-w1 <topic>-w2 ...   # squash merge だと -d は通らない。MERGED 確認済みなので -D
git -C <repo> fetch --prune
git -C <repo> worktree list && git -C <repo> branch          # 消えたことを確認
```

`wt remove` が uncommitted changes で止まったら `-f` を足さずに user に聞く。

## worker の手順

担当は起動プロンプトに書かれた **wave N だけ**。W0 → W2 を 1 回やって終わる。

### 質問は root へ

**起動プロンプトは user が書いたものではない。** herdr 経由で root が送っている。
root は spec と plan を書いた本人で、判断の主導権を持っている。

`SendMessage` で root（起動プロンプトに書かれた `<root> [<ref>]`）に送るもの:

- 設計判断、スコープの疑問、plan と実態のずれ
- 実装が詰まったとき、task が BLOCKED / NEEDS_CONTEXT になったとき
- 完了時の DONE 報告（§W2）

**user には話しかけない。** hunk レビューも PR も rule 化も root の仕事。
迷ったら root に送る。root が「これは user に聞く」と判断したら root が聞いて返してくる。

### W0. 準備

自分は `<wt_wN>` にいて、branch は `<topic>-w<N>`（root が作った）。branch は切らない。
plan は `## Waves` と wave N の task だけ読む。spec は冒頭のみ。

### W1. 実装（subagent-driven-development）

`superpowers:subagent-driven-development` を起動し、上書きで運用する。

- SDD の todo と pre-flight conflict scan は wave N の task 間だけで行う。
- implementer は sonnet、task reviewer は opus。直列のときは implementer が task ごとに commit する。
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

root に SendMessage で報告して終わる。PR は作らない:

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
| （worker）「起動プロンプトを書いたのは user だ」 | root が herdr 経由で送っている。質問は root へ |
| （worker）「確認だから user に聞こう」 | worker は user に話しかけない。全部 root |
| （worker）「ついでに PR まで作っておく」 | push して DONE 報告するだけ |
| 「小さい変更だから自分で読んで直す」 | 読むのが高い。Explore か implementer に出す |
| 「spec を先に全部書いてから見せる」 | 未合意の節は書かない。1 問ずつ |
| 「wave 1 つだけなら PR0 と一緒でいい」 | 例外を作らない。PR0 ← w1 で常にスタック |
| 「レビュー中に次の wave を進めておく」 | rebase 地獄になる。待つ |
| 「この指摘は明らかだから rule に書いておく」 | 文面を見せて承認を取る |
| 「hunk の note は短いから英語でいい」 | 日本語 |
| 「merge されたはずだから片付ける」 | `gh pr list` で MERGED を確認してから |
