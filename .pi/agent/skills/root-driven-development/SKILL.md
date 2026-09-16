---
name: root-driven-development
description: Root が user と要件・実装フェーズを合意し、自ら実装して各フェーズを tuicr レビューで止める開発フロー
disable-model-invocation: true
---

# Root-driven development

root が会話・判断・すべての編集を持ち、subagent は判断材料だけを返す。root は test code を書くが、その実行を含む検証作業は subagent が行う。user が現在のフェーズを承認するまで working tree を次のフェーズへ進めない。

## 責務

| 担当 | 責務 |
| --- | --- |
| root | user との会話、要件整理、フェーズ設計、source / test / docs の実装と指摘修正 |
| subagent | 必要になった調査・探索・検証コマンドの実行を read-only で行い、証拠を root へ返す |
| user | 要件とフェーズの合意、`tuicr` レビュー、フェーズ承認、Git 操作の判断 |

この Skill の実行中はこの役割分担を優先する。`orchestrating-development`、`delegating-small-tasks`、`subagent-driven-development`、`executing-plans` に実装を渡さない。TDD などの技法は root が使い、テスト実行のような検証は下記の分担に従う。

## Workflow

1. **開始状態を固定する**
   - repository の status を読み、開始前からある差分を記録する。
   - 既存差分を今回の成果として扱わない。
   - `status` / `diff` など read-only の VCS 確認は workflow 管理なので root が直接実行してよい。test / build / lint / 再現 / 動作確認は検証として subagent へ委譲する。

2. **要件を合意する**
   - root が必要な質問を一度に1問ずつ user へ聞く。
   - 必要なら、質問前または回答後に調査・探索を subagent へ出す。
   - `目的 / 対象 / 完了条件 / 対象外` をチャットで提示する。
   - user の承認を得てからフェーズ設計へ進む。

3. **全フェーズを合意する**
   - root が全フェーズ案をチャットで提示する。各フェーズには `成果` と判定可能な `完了条件` を付ける。
   - user と修正し、全体の承認を得る。
   - 承認後、1フェーズを1つの todo にする。in progress は常に1つだけ。task-list tool が無い環境では、同じ一覧と現在位置をチャットに保つ。
   - spec / plan ファイルは作らない。

4. **現在のフェーズを実装する**
   - root が対象ファイルを読み、source / test / docs のすべての編集を行う。
   - 具体的な未知事項が生じた時だけ、調査・探索・検証を subagent へ委譲する。毎フェーズの儀式として verifier を起動しない。
   - 検証が必要だと判断した後は、短い test / build / lint / 再現コマンドでも subagent が実行する。root は先に試さず、並行して同じ確認をせず、結果だけを解釈する。
   - subagent の報告を判断材料にし、必要な変更は root が行う。

5. **user review gate で止める**
   - 開始状態との差分を確認し、現在のフェーズに属する変更だけを報告する。
   - 変更は unstaged のまま保つ。
   - `できるようになったこと / 変更ファイル / 検証と証拠 / 未解決事項` を示し、user に repository root で `tuicr` を実行するよう伝える。
   - ここで応答を終える。明示承認までは次フェーズのコードに触れない。
   - 指摘は同じフェーズ内で root が修正し、この gate を繰り返す。
   - 承認後に現在の todo を完了し、次の todo を in progress にする。残りのフェーズが変わる場合は、更新案を user と再合意する。

Git の stage / commit / push はこの Workflow の外に置く。フェーズ承認から Git 操作の許可を推測せず、別の明示指示に従う。

## Subagent contract

| 目的 | Pi | Claude Code |
| --- | --- | --- |
| コードベース探索 | `scout` | `Explore` |
| 外部・ライブラリ調査 | `researcher` | 調査可能な read-only agent |
| テスト・挙動検証 | `worker` に no-edit を明示 / 静的確認は `reviewer` | `general-purpose` に no-edit を明示 |

各依頼に `目的 / cwd / 対象範囲 / read-only 境界 / 完了条件 / 必要な証拠 / 報告形式` を含める。`worker` / `general-purpose` は編集 tool を持ち得るため、read-only は agent 名でなく dispatch の権限境界として明示する。subagent は編集、stage、commit、user への質問を行わない。独立した依頼だけを並列化する。subagent 経路が使えない場合は exact failure を user に報告し、root が黙って代行しない。

## Red flags

| 誘惑 | この Workflow の判断 |
| --- | --- |
| 「root-driven は指揮だけ。worker が実装してよい」 | root が全編集を行う。subagent は証拠だけを返す |
| 「checkpoint commit なら review を保てる」 | user は unstaged diff を見る。Git 操作は別の明示指示を待つ |
| 「緊急なので review 中に次へ進む」 | 緊急性を user へ伝え、現在の gate で止まる |
| 「20秒のテストなら root が直接回す方が速い」 | 必要性を決めるのは root、検証コマンドを実行するのは subagent。速さ・root の最終責任・併用を理由にした hybrid も不可 |
| 「未 commit なら次フェーズを始めてもよい」 | 同じ working tree の review 対象を変えない |
