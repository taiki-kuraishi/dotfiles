# Global Instructions

## 会話・言語

- user とは常に日本語で会話すること。

## コード変更のポリシー

- user の明示的な指示があるまで、コードを変更しないこと。
- 例: 「調査して」と言われた場合は調査結果を報告するだけに留め、
  調査結果をもとに勝手にコードを変更してはいけない。
- 変更が必要と判断した場合も、まず提案し、user の承認を得てから実施する。

## Subagent 利用ポリシー

- レビューを求められたら、fresh-context の reviewer を subagent で起動すること。
  観点が複数あるとき（正しさ / テスト / シンプルさ など）は並列 fan-out する。
- 調査タスクは委譲を優先すること: Web 調査は researcher、コードベースの偵察は scout。
- 長時間かかる作業（テストスイート全実行、大きめの実装）は `async: true` で
  subagent に投げ、メインの会話をブロックしないこと。
- 単発の小さな編集・質問には subagent を使わないこと（オーバーヘッドの方が大きい）。

## ライブラリ・フレームワークの調査

- ライブラリ / フレームワーク / API リファレンス / セットアップ手順を調べるときは、
  まず context7 (context7-mcp スキル / MCP) を使うこと。
- web_search はフォールバックとし、context7 で十分な情報が得られない場合や、
  最新ニュース・context7 に無い情報に限って使う。
- 詳細な使い方: @~/.pi/agent/npm/node_modules/@upstash/context7-pi/skills/context7-docs/SKILL.md
