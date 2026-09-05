---
name: delegating-small-tasks
description: Use when the user asks for a small change, fix, investigation, or check in a repo that does not warrant a spec, a plan, or a separate worker session — 「ちょっと直して」「これ調べて」「テスト通して」「この関数を〜に変えて」, "quick fix", "look into X", "check whether Y works". Also use when the user says 「小さいタスク」「sub agent にやらせて」. Not for multi-wave features with a plan (use orchestrating-development).
---

# Delegating small tasks

session を分けるほどではない小さな仕事を、**root が相談相手になりつつ、手を動かすのは subagent** でこなす。

> 注意：あなたの主なタスクは分析、編排、検証です。具体的なタスクは可能な限り subagent（Opus または Sonnet）に
> 実行させます。自分は要件の明確化、方案の分解、タスクの分配、結果の受け入れだけを行い、実装類の作業
> （大量のコード読み込み、コード執筆、テスト実行、批量修正）はすべて Agent ツールを使って subagent に
> 割り当てて実行させます。

## 自分がやること / やらないこと

| やる | やらない |
| --- | --- |
| 依頼の不明点を user に聞く（必要な分だけ、1 問ずつ） | ファイルを開いて読む |
| 仕事を subagent 単位に分解して `Agent` で出す | コードを書く、直す |
| 報告を読んで受け入れる、突き返す | テストを自分で回す |
| user に結果を報告する | git 操作（user が言ったときだけ） |

spec も plan も書かない。設計の合意も取らない。user は root に相談したいだけで、儀式は要らない。

## 委譲先

| 工程 | `subagent_type` | model |
| --- | --- | --- |
| 探索・調査・ライブラリ確認 | `Explore` | sonnet |
| 実装・修正 | `general-purpose` | sonnet |
| テスト実行・検証・デバッグ | `general-purpose` | sonnet |
| レビュー（正しさ、docs 整合、ponytail） | `general-purpose` | **opus** |

`model` は毎回明示する。独立した仕事は 1 つの応答で同時に出す。

## 流れ

1. 依頼を読む。曖昧なら `AskUserQuestion`。曖昧でなければ聞かない。
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
| 「1 ファイルだから自分で見る」 | 読むのが高い。Explore に出す |
| 「小さい修正だから自分で書く」 | implementer に出す。自分は dispatch 文を書く |
| 「implementer が通ったと言っている」 | 別の subagent に検証させる |
| 「ついでに commit しておく」 | user が言うまで git は触らない |
| 「まず設計を固めよう」 | この skill に設計工程は無い。聞くのは不明点だけ |
