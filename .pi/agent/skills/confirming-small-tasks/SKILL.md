---
name: confirming-small-tasks
description: Use when the user asks for a small change, fix, investigation, or check and wants to agree on files and interfaces before implementation, or wants reviews only on request — 「確認しながら進めたい」「投げる前に合意したい」「勝手にレビューしないで」. Not for multi-wave features with a plan (use orchestrating-development). Use delegating-small-tasks instead when speed matters and automatic review is fine.
---

# Confirming small tasks

`delegating-small-tasks` の派生。違いは2点だけ: 投げる前の interface 合意と、指示ベースのレビュー。他は原本と同じ。

Claude Code と pi の両方で使う。本文の手順は Claude Code を主文とし、pi では対応表・各節の注記（`ClaudeではX / piではY`）に従って読み替える。

session を分けるほどではない小さな仕事を、**root が相談相手になりつつ、手を動かすのは subagent** でこなす。ただし worker へ投げる前に user と interface を固定し、レビューは user の指示または確認があってから回す。

> 注意：あなたの主なタスクは分析、編排、検証です。具体的なタスクは可能な限り subagent（Opus または Sonnet。pi では対応表に従い `scout` / `researcher` / `worker` / `reviewer` など）に
> 実行させます。自分は要件の明確化、方案の分解、タスクの分配、結果の受け入れだけを行い、実装類の作業
> （大量のコード読み込み、コード執筆、テスト実行、批量修正）はすべて Agent ツール（pi では `subagent`）を使って subagent に
> 割り当てて実行させます。

## 自分がやること / やらないこと

| やる | やらない |
| --- | --- |
| 依頼の不明点を user に聞く（必要な分だけ、1 問ずつ） | 3コール超の読み書き・実行（コード修正・テスト・複数ファイル調査） |
| worker へ投げる前に interface（触るファイル、関数シグネチャ、入出力、完了条件）を user と固定する | 合意前の dispatch、合意文面と違う依頼文 |
| 仕事を subagent 単位に分解して `Agent`（pi では `subagent`）で出す | コードを書く、直す |
| 報告を読んで受け入れる、突き返す | テストを自分で回す |
| レビューは user の指示で回す。指示がなければ commit / push 前に回すか確認する | 指示・確認なしのレビュー |
| user に結果を報告し、レビュー（承認 or 指摘）を求める | 承認前の commit / push / PR |

合意も儀式にしない。固定するのはファイル+入出力だけ。spec も plan も書かない。

## 直接作業の上限（3コールルール）

root の直接 tool 使用は**合計3コール以内の確認・参照**に限定する（例: 状態確認、subagent 報告の読み返し）。
次に当てはまる作業は必ず subagent に委譲する: 見込み3コール超、コードの読み書き・修正、テスト実行・デバッグ、複数ファイルに跨る調査、大量出力が見込まれるコマンド。
数えるのはコードベースへの読み書き・実行（read / bash / edit / write 等）のみ。subagent の起動と user への質問・合意は数えない。
理由は root の context 温存＝判断力の維持。迷ったら出す。

## 委譲先

| 工程 | 委譲先（Claude / pi） | model（Claude / pi） |
| --- | --- | --- |
| 探索・調査・ライブラリ確認 | `Explore` / `scout`（コード偵察）・`researcher`（Web 調査） | sonnet / session 継承 |
| 実装・修正 | `general-purpose` / `worker` | sonnet / session 継承 |
| テスト実行・検証・デバッグ | `general-purpose` / `worker`（実装者とは別個体） | sonnet / session 継承 |
| レビュー（user の指示があった観点のみ） | `general-purpose` / `reviewer` | **opus** / session 継承 |

対応表（Claude ⇔ pi）:

| 項目 | Claude | pi | 備考 |
| --- | --- | --- | --- |
| 探索・偵察 | `Explore` | `scout` | |
| 汎用実行・実装 | `general-purpose` | `worker` | |
| Web 調査 | `general-purpose` に含む | `researcher` に分離 | pi のみ分離 |
| review 系 | `general-purpose` | `reviewer` | |
| 軽量 / 重量モデル | sonnet / opus | session 継承 | pi で明示名は使わない |
| user への質問 | `AskUserQuestion` | 質問ツール | |
| dispatch | `Agent` | `subagent` | 並列は `workflowScript + runs.all`（pi） |

`Agent` の `model` は毎回明示する（以上 Claude）。pi では逆に session の model を継承する。独立した仕事は 1 つの応答で同時に出す（pi では `runs.all` で fan-out）。

## 流れ

1. 依頼を読む。曖昧なら `AskUserQuestion`（pi では質問ツール）。曖昧でなければ聞かない。
2. interface を user と固定する。決めるのは4点だけ: 触るファイル、関数シグネチャ、入出力、完了条件。
   合意した文面をそのまま step 3 の dispatch 文に転記する。合意なしに投げない。
3. subagent ごとに dispatch 文を書く。必ず入れるもの: 目的、対象（ファイル / 範囲）、step 2 の合意文面（そのまま引用）、
   完了条件、報告形式（変更ファイル一覧、実行したコマンドと結果、懸念）。テンプレ:

   ```text
   目的: <1行>
   対象: <ファイル / 範囲>
   合意した interface: <step 2 の文面をそのまま>
   完了条件: <合意通り + 既存テストが通る>
   報告: 変更ファイル一覧、実行コマンドと結果、懸念
   制約: 合意外のファイルに触らない。迷ったら止めて報告する。
   ```

4. **実装した subagent に自己申告させない。** 検証は別の subagent に出す（テスト実行、動作確認）。
5. レビューは自動で回さない。user の指示がある観点だけ回す。指示がなければ commit / push 前に
   「レビュー回す? 観点は?」と確認し、承認された観点だけ回す。
   各 reviewer には session 履歴を渡さず、未 commit の diff と対象ファイルを渡す。
   観点の候補は原本と同じ3つ: ponytail（skill `ponytail-review`）、docs 整合（`doc-drift-detector`、
   または `reviewer` + skill `detecting-doc-drift`）、正しさ（skill `requesting-code-review` の
   `code-reviewer.md` の観点を `reviewer` に渡す）。
   指摘は重みで分ける: P0/P1 は implementer に戻して直す。P2 は直さず step 6 の報告に載せる。
   指摘ゼロ・全て対応不要ならそのまま step 6 へ。指摘が矛盾する場合や implementer が根拠付きで
   反論した場合は自分で裁定せず、両論を step 6 で user に併記する。review→fix の往復は最大2回。
   差分が出なかった依頼（調査だけ、テスト実行だけ、変更不要と判明した場合）はこのステップを飛ばして step 6 へ進む。
6. user に報告する。何をしたか、変更ファイル、実行したコマンドと結果、step 5 を回した場合はレビュー
   指摘と対応、未追跡ファイル（`git status --short` で確認）、懸念。
   **レビューが済んだら、user にレビュー（承認 or 指摘）を求める。** diff を見たいときの
   コマンドを添える（lockfile 除外済み）:

   ```text
   git diff -- . ':!*.lock' ':!*.lockb' ':!*-lock.json' ':!*-lock.yaml' ':!go.sum'
   ```

   差分が無く step 5 を飛ばした場合は報告のみで、承認要求は不要。
7. user の承認が得られたら commit してよい。push / PR は **user が言ったときだけ**。

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| 「1 ファイルだから自分で見る」 | 1〜2コールの参照なら直接可。深掘り・複数ファイルに広がったら Explore に出す（pi では scout） |
| 「小さい修正だから自分で書く」 | コード修正は規模によらず implementer に出す（Claude: `general-purpose` / pi: `worker`）。自分は dispatch 文を書く |
| 「合意は取ったつもり」 | 文面で固定していない合意は無い。4点を書いて user に見せてから投げる |
| 「implementer が通ったと言っている」 | 別の subagent に検証させる |
| 「レビュー3本を回しておく」 | 指示・確認なしに回さない。先に commit / push 前の確認を取る |
| 「ついでに commit しておく」 | 承認前に commit しない。user の承認後に commit してよい |
| 「まず設計を固めよう」 | 固定するのはファイル+入出力だけ。この skill に spec・plan 工程は無い |
