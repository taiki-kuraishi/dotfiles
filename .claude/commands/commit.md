---
description: 変更をコミットする（英語1行・prefix付き・emoji default ON）
argument-hint: "[--no-emoji] [context]"
---

$ARGUMENTS を引数として受け取り、現在のリポジトリの変更をコミットする。

## 引数
- `--no-emoji` がなければ message 先頭に gitmoji を付ける（default ON）。
- `--no-emoji` 以外の残りはコミット内容のヒント。なければ diff から推測する。

## 手順
1. `git status --short` と `git diff --stat` で変更を把握する。`git log --oneline -10` で既存 message の prefix 流儀を確認し合わせる。
2. 関係するファイルだけ `git add <paths>` で stage する（`git add -A` の丸投げ禁止。無関係な変更は除外）。
3. message は英語1行のみ、`<emoji> <prefix>: <summary>`（`--no-emoji`時は`<prefix>: <summary>`）。prefix は feat / fix / refactor / docs / chore / test 等から diff に合うものを選ぶ。description（body）は書かない。
4. `git commit -m "<message>"` を1回だけ実行する。`Co-authored-by` を絶対に含めない。
