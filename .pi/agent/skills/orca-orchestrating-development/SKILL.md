---
name: orca-orchestrating-development
description: Use when the user asks to build, implement, refactor, or fix something with Orca-managed child worktrees as workers — 「orcaで実装して」「子worktreeでworkerを」「orca版orchestrating-development」「worker mode で orca-orchestrating-development」。Orca CLI owns checkouts, lineage, and worker terminals; spec / plan / waves flow mirrors orchestrating-development. Not for questions, spikes, or one-line fixes with no plan.
---

# Orca orchestrating development

**spec / plan を root session が書き、実装は子worktreeの worker session に委譲し、
user は hunk で PR をレビューする**流れは `orchestrating-development` と同じ。
違うのは worktree の owner と worker session の置き場所だけ：

| | orchestrating-development | このスキル |
| --- | --- | --- |
| worktree owner | `wt` | `orca worktree create` |
| 親子関係 | なし（herdr label規約のみ） | `--parent-worktree` lineage（`parentWorktreeId` / `childWorktreeIds`） |
| worker session | herdr workspace + agent | 子worktreeの first terminal（`--agent` + `--prompt`） |
| 進捗参照 | `herdr agent read` | `orca terminal read` |
| 報告線 | pi `intercom` | pi `intercom`（同じ） |
| 片付け | herdr close + `wt remove` | `terminal close --all` + `worktree rm` |

工程・委譲・言語ルールは `orchestrating-development` に準拠する。
このスキルに書いてあるのは **orca差分だけ**。書いてない運用は向こうを見る。

## バイナリとモード

`ORCA` は `orca-cli` スキルの解決ルールに従う。Orca コマンドの前に
`ORCA skills get orca-cli` でバージョン一致ガイドを読む。毎回 `--json`。
`orca` / `orca-ide` の直書きはしない。

モード判定は `orchestrating-development` と同じ。worker trigger の文言だけ
「worker mode で orca-orchestrating-development」になる。

## 配置の制約（検証済み）

- `worktree create` に `--path` はない。checkout先は Orca が決める
  （`~/orca/workspaces/<repo>/<name>`）。`--parent-worktree` は lineage
  （見た目の親子）だけで場所は変えない。
- wave worktree の parent は必ず **main の worktree**。spec worktree の子にしない
  （stack禁止。§R4 と同じ理由）。
- branch 名は `<topic>` / `<topic>-w<N>` の慣例を維持（herdr互換）。

## root の手順

### R1. brainstorming

`orchestrating-development` §R1 と同じ。topic と branch 名 `<topic>` を決めたら
spec 用の子worktreeを作る（main checkout の中で。parent は推論＝main）。
`<repoId>` は `ORCA repo list --json` で取る（以降の `--repo` に使う）：

```bash
ORCA worktree create --repo id:<repoId> --name <topic> --comment "spec/plan作成中" --json
mkdir -p <wt>/docs/superpowers/specs <wt>/docs/superpowers/plans
```

`<wt>` は `result.worktree.path`。`--agent` 無しの first terminal は予備シェルに
なる（R3 で一緒に閉じる）。

spec の置き場所・追記ルール・self-review は §R1 と同じ。

### R2. writing-plans

§R2 と同じ。`Depends on:` と `## Waves`、1 wave = 1 PR = 1 worker。

### R3. PR0（spec + plan）

§R3 と同じ（`git` / `gh` は `<wt>` をカレントに）。merge 後の片付けだけ orca：

```bash
ORCA terminal close --worktree <R1で控えたworktree id> --all --json
ORCA worktree rm --worktree <R1で控えたworktree id> --force --json
git -C <repo> pull --ff-only
```

`rm` が file watcher / PTY の `unverifiable` で詰まったら無理押ししない。
フォールバック：`git -C <repo> worktree remove --force <wt>` → branch `-D`
（unmerged の `-D` は user 許可後のみ。§R7 と同じ）。

### R4. wave N の worker を起動

plan 全体を渡さない・stack しない（§R4 と同じ）。main を最新にして：

```bash
git -C <repo> pull --ff-only
ORCA worktree create --repo id:<repoId> --name <topic>-w<N> \
  --parent-worktree worktree:<mainのid全文> \
  --agent <agent-id> --prompt "<worker brief>" --json
```

- parent 用の main の id は `worktree list --repo id:<repoId>` の main の
  `id` フィールドをそのまま使う（自前で組み立てない）。
- `--agent` は導入済み TUI agent の id（pi / claude / codex 等）。
  first terminal の owner になり、以降その agent には `terminal create` しない。
- create 直後に起動確認：`result.agentTerminalHandle` が取れること。
  なければ `terminal list --worktree <作ったworktreeのid>` で探し、
  見つからなければ起動失敗として user に報告する
  （sole-handle ルールは `orca-cli` 参照）。
- `<worker brief>` はこの一文で始める：
  「worker mode で orca-orchestrating-development スキルに従ってください。」
  続けて：担当 wave N の task 一覧と `## Global Constraints` /
  `<wt_wN>`（`result.worktree.path`）/ branch / spec・plan パス /
  root の intercom target（§R4-1 の手順で控えた session name か session ID。
  brief の必須要素）/ DONE 報告形式 / PR は作らない。
  複数行 brief はシェル quoting に注意。
- create は即時復帰する。完了待ちループを入れない
  （待つと worker の質問に答えられない。§R4 と同じ）。

branch / worktree id / agent handle を user に報告して R5 へ。

### R5. 応答

§R5 と同じ。質問は `intercom` の `reply` で返す。進捗確認は：

```bash
ORCA terminal read --terminal <handle> --limit 100 --json   # 続きは --cursor paging
```

root は実装しない。`terminal send` は一言の指示に限定し、議論は `intercom` で。

### R6. wave の統合（worker の DONE 後）

worktree は merge まで残す。3 体 review の同時出し・push・draft PR・CI・
hunk 依頼・指摘回収は §R6 と同じ。読み替えだけ：

- subagent の作業場所は `<wt_wN>`（`cd <wt_wN>`。root は branch を切り替えない）。
- hunk 依頼文の `cd <wt_wN>` は orca の `result.worktree.path`。
- merge 後の片付け：

```bash
ORCA terminal close --worktree <R4で控えたworktree id> --all --json
ORCA worktree rm --worktree <R4で控えたworktree id> --force --json
git -C <repo> pull --ff-only
```

詰まり時のフォールバックは §R3 と同じ。次の wave（R4 の N+1）へ。

### R7. 片付け（「片付けて」）

```bash
ORCA worktree list --repo id:<repoId> --json
git -C <repo> worktree list && git -C <repo> branch --list '<topic>*'
gh pr list --state all --limit 100 --json number,headRefName,state
```

`MERGED` 確認済みだけ消す（close → rm → branch `-D`）。未 merge は止まって user に聞く。

## worker の手順

担当は起動プロンプトの **wave N だけ**。W0（準備）・W1（SDD）・W2（push と DONE 報告）は
§W0–W2 と同じ。差分：

- branch は orca が切った `<topic>-w<N>`。自分で切らない。
- **自分の terminal を orca CLI で操作しない**（`terminal read/send/close` の
  target に自分を指定しない。unverifiable の元）。
- 質問・DONE は `intercom` で root へ。`ask`＝質問・判断待ち、`send`＝進捗・DONE。
  target が brief になければ `intercom list` で探す。user には話しかけない。
- PR は作らない。push して DONE 報告で終わり。

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| 「`--agent` の後に `terminal create` で agent を」 | 二重起動。`--agent` が first terminal の owner |
| 「worktree id を手で組み立てる」 | `create` / `list` の `id` 全文をそのまま使う |
| 「`rm` の前に close は不要」 | 要る。生 PTY が残ると watcher が詰まる |
| 「worker が自分の terminal を `terminal read`」 | 自分を target にしない |
| planning 全般の間違い | `orchestrating-development` の表を見る |
