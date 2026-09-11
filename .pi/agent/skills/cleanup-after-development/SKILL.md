---
name: cleanup-after-development
description: Use when development work driven by orchestrating-development, delegating-small-tasks, or a Herdr/worktree handoff is finished and the leftover artifacts need to go — 「片付けて」「消して」「後片付け」「cleanup」, "clean up the worktree", "remove the branch". Removes Herdr workspaces, git worktrees, branches, and /tmp scratch files, in that order. Does not touch docs/superpowers/**, .superpowers/sdd/**, ~/.pi/**, or git-ignored files. Use herdr-worktree-handoff for handing work OFF; use this skill to tear it down after the fact. Prefer this skill over herdr-worktree-handoff when the goal is teardown rather than handing work off.
---

# 開発後の片付け

開発が終わったあとに残ったものを、確認してから順番に畳む。対象は Herdr workspace、
git worktree、branch、そして作業中に作った `/tmp` のエントリ。どの skill で開発しても
入口はここ 1 つでよい（`orchestrating-development`、`delegating-small-tasks`、
`herdr-worktree-handoff` 経由の worker のいずれでも）。

## 道具の分担

worktree は `wt`（worktrunk）が、workspace とペインは Herdr が持つ。削除でも混同しやすい
ので先に確定させる。

| コマンド | 何を消すか |
| --- | --- |
| `herdr workspace close <workspace_id>` | workspace とペインのプロセスを閉じるだけ。worktree ディレクトリも branch も消さない |
| `wt -C <repo> remove <branch> --foreground` | worktree ディレクトリを消し、merged なら branch も消す |
| `herdr worktree remove --workspace <ID> [--force]` | 存在するが branch 削除のパラメータが無く、正典の手順では使っていない。使わない |

`wt remove` のフラグ:

- `-f` = worktree が dirty でも消す
- `-D` = 未 merge の branch も消す
- `--no-delete-branch` = branch を残す

このマシンは **wt 0.77.0 / herdr 0.9.0**。同梱の `herdr-worktree-handoff` は wt 0.72 /
herdr 0.8 で検証されたものなので、挙動が怪しければ `wt remove --help` /
`herdr worktree remove --help` で確認する。

## 前提

`$HOME` は yadm が管理している。plain `git` は $HOME 直下では `fatal: not a git
repository` になるか、別のリポジトリを見てしまうので使わない。対象リポジトリは必ず `-C` で
明示する。

```bash
git -C <repo> status          # 対象リポジトリ
wt -C <repo> remove <branch> --foreground  # 対象リポジトリ（実行は §2 の確認後）
```

Herdr の中で作業した場合にだけ herdr コマンドを使う。`test "${HERDR_ENV:-}" = 1` で確認し、
Herdr の外なら herdr の行は飛ばす（worktree と branch の削除だけで足りる）。

## 1. 在庫確認（読み取りのみ）

この段階では何も消さない。

```bash
herdr workspace list                    # label が作業中の branch と一致するものを探す
git -C <repo> worktree list             # worktree の path 一覧
git -C <repo> branch --list '<topic>*'  # <topic> と <topic>-w<N>
gh pr list --state all --limit 100 --json number,headRefName,state   # 対象リポジトリの中で実行する（$HOME では git が無くて失敗する）
ls -la /tmp                             # 作業で作ったエントリだけを拾う
```

## 2. 一覧提示と確認

user に 1 回だけ見せる。

- workspace id と label
- worktree path
- branch 名
- PR の merge 状態
- 消す予定の `/tmp` パス

種別ごとに何度も聞かない。この 1 回で確認を取ってから削除に進む。

## 3. 削除（この順序）

土台は `herdr-worktree-handoff` の「Reporting and cleanup」節が持つ手順で、その順番どおりに
呼ぶ。この skill が足すのは、`wt remove` が branch を残したときの後始末だけ。それ以外の
フラグを勝手に増やさない。

```bash
herdr workspace close <workspace_id>          # 先。worker の claude もここで終わる
wt -C <repo> remove <branch> --foreground     # worktree を消す。merged なら branch も消える
git -C <repo> branch -d <branch>              # wt が branch を残した場合のみ。-d は merged でないと失敗する
```

この `-d` / `-D` は git branch の削除。`wt remove -D`（未 merge の branch も消す）とは別物。
未 merge の branch を捨てるには user の明示が要る。

`wt remove -D` と `-f` は不可逆。user が「その branch / 変更は捨ててよい」と言った時だけ付ける。
言われていないなら `wt remove` のエラーで止めて user に聞く。worktree が dirty で
`wt remove` が失敗したときも、勝手に `-f` を足さず user に聞く。

## 4. 一時ファイル

消すのは**作業中に作った `/tmp` のエントリだけ**。パスを明示して消す。

```bash
rm -rf -- /tmp/<name>
```

`<name>` は具体的な 1 エントリ名に置換する。空やグロブのまま実行しない。

- **git-ignored なファイルは消さない**（`git clean` は使わない）。
- **`~/.pi` 配下は触らない**（subagent の artifact を含む）。
- `/tmp` を丸ごと消す・`rm -rf /tmp`・ワイルドカードでの一括削除は禁止。

## 5. 確認

```bash
git -C <repo> worktree list && git -C <repo> branch
herdr workspace list
```

worktree と branch、workspace がそれぞれ消えたことを user に示す。

## 残すもの

- `docs/superpowers/specs/**` と `docs/superpowers/plans/**` — orchestrating-development §R7 が成果物として残すと指定している
- `.superpowers/sdd/**` — worktree の中にある分は worktree の削除で一緒に消える。「個別に消しに行かない」の意
- `~/.pi/**`
- git-ignored なファイル

## よくある間違い

| 思考 | 現実 |
| --- | --- |
| 「workspace を閉じれば worktree も消える」 | 消えない。`wt remove` が別途必要 |
| 「PR が merged だから branch も消してよい」 | merged なら `wt remove` / `git branch -d` で消せる。ただし `git branch -D`（force）と `wt remove -D` は別のスイッチで、どちらも「その branch は捨ててよい」と user が言うまで付けない |
| 「ignored なファイルはどうせ要らない」 | 消さない。`git clean` は使わない |
| 「$HOME で `git status`」 | yadm のリポジトリは見えないか、別のリポジトリを見る。必ず `-C <repo>` |
| 「delegating-small-tasks 経由でも worktree があるはず」 | あの skill は worktree も branch も作らない。消すものが無ければそれで正常終了 |
