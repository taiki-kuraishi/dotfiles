---
name: delegating-small-tasks
description: Use when the user asks for a small change, fix, investigation, or check in a repo that does not warrant a spec, a plan, or a separate worker session — 「ちょっと直して」「これ調べて」「テスト通して」「この関数を〜に変えて」, "quick fix", "look into X", "check whether Y works". Also use when the user says 「小さいタスク」「sub agent にやらせて」. Not for multi-wave features with a plan (use orchestrating-development). Works in both Claude Code and pi sessions; tool names that differ between the two map per the correspondence table below (`ClaudeではX / piではY` の読み替えで両対応).
---

# Delegating small tasks

Claude Code と pi の両方で使う。本文の手順は Claude Code を主文とし、pi では下の対応表・各節の注記（`ClaudeではX / piではY`）に従って読み替える。

session を分けるほどではない小さな仕事を、**root が相談相手になりつつ、手を動かすのは subagent** でこなす。

> 注意：あなたの主なタスクは分析、編排、検証です。具体的なタスクは可能な限り subagent（Opus または Sonnet。pi では対応表に従い `scout` / `researcher` / `worker` / `reviewer` など）に
> 実行させます。自分は要件の明確化、方案の分解、タスクの分配、結果の受け入れだけを行い、実装類の作業
> （大量のコード読み込み、コード執筆、テスト実行、批量修正）はすべて Agent ツール（pi では `subagent`）を使って subagent に
> 割り当てて実行させます。

## 自分がやること / やらないこと

| やる | やらない |
| --- | --- |
| 依頼の不明点を user に聞く（必要な分だけ、1 問ずつ） | ファイルを開いて読む |
| 仕事を subagent 単位に分解して `Agent`（pi では `subagent`）で出す | コードを書く、直す |
| 報告を読んで受け入れる、突き返す | テストを自分で回す |
| user に結果を報告する | git 操作（user が言ったときだけ） |

spec も plan も書かない。設計の合意も取らない。user は root に相談したいだけで、儀式は要らない。

## 委譲先

| 工程 | 委譲先（Claude / pi） | model（Claude / pi） |
| --- | --- | --- |
| 探索・調査・ライブラリ確認 | `Explore` / `scout`（コード偵察）・`researcher`（Web 調査） | sonnet / session 継承 |
| 実装・修正 | `general-purpose` / `worker` | sonnet / session 継承 |
| テスト実行・検証・デバッグ | `general-purpose` / `worker`（実装者とは別個体） | sonnet / session 継承 |
| レビュー（正しさ、docs 整合、ponytail） | `general-purpose` / `reviewer` | **opus** / session 継承 |

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
2. subagent ごとに dispatch 文を書く。必ず入れるもの: 目的、対象（ファイル / 範囲）、完了条件、
   報告形式（変更ファイル一覧、実行したコマンドと結果、懸念）。
3. **実装した subagent に自己申告させない。** 検証は別の subagent に出す（テスト実行、動作確認）。
4. user に報告する。何をしたか、変更ファイル、テスト結果、懸念。diff を見たいときの
   コマンドを添える（lockfile 除外済み）:

   ```text
   hunk diff -- . ':!*.lock' ':!*.lockb' ':!*-lock.json' ':!*-lock.yaml' ':!go.sum'
   ```

5. 指摘があれば implementer に戻す。commit / push / PR は **user が言ったときだけ**。

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| 「1 ファイルだから自分で見る」 | 読むのが高い。Explore に出す（pi では scout） |
| 「小さい修正だから自分で書く」 | implementer に出す（Claude: `general-purpose` / pi: `worker`）。自分は dispatch 文を書く |
| 「implementer が通ったと言っている」 | 別の subagent に検証させる |
| 「ついでに commit しておく」 | user が言うまで git は触らない |
| 「まず設計を固めよう」 | この skill に設計工程は無い。聞くのは不明点だけ |
