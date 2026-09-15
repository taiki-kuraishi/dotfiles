---
description: PRを作成する（title英語・body日本語・default draft・自分をassign）
argument-hint: "[--no-emoji] [--ready] [context]"
---

$ARGUMENTS を引数として受け取り、現在のブランチから PR を作成する。

## 引数
- `--no-emoji` がなければ title 先頭に gitmoji を付ける（default ON）。
- `--ready`（別名 `--no-draft`）がなければ draft で作成する（default draft）。
- 上記以外は PR 内容のヒント。なければ diff から推測する。

## 手順
1. `git status --short`、`git log --oneline @{u}..HEAD`（upstream がなければ `git log --oneline -10` で代用）、`git diff @{u}...HEAD --stat` で内容を把握する。未 push なら `git push -u origin HEAD` を先に行う。
2. title は英語1行、`<emoji> <prefix>: <summary>`（`--no-emoji`時は`<prefix>: <summary>`）。prefix は feat / fix / refactor / docs / chore / test 等から選ぶ。
3. body は日本語で書く。`pull_request_template.md` / `PULL_REQUEST_TEMPLATE.md` / `.github/pull_request_template.md` / `.github/PULL_REQUEST_TEMPLATE/` 配下のテンプレートがあればその構成に従う。なければ「概要 / 変更内容 / 確認方法」の3節にする。
4. `gh pr create --draft --assignee @me --title "<title>" --body "<body>"` で作成する。`--ready` 指定時のみ `--draft` を外す。
