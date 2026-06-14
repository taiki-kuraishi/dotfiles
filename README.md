# dotfiles

[yadm](https://yadm.io/) で管理する dotfiles。`$HOME` を git のワークツリーとして実ファイルを配置する方式（シンボリックリンク不使用）。

## セットアップ（新しいマシン）

```sh
brew install yadm
yadm clone https://github.com/taiki-kuraishi/dotfiles.git
```

`yadm clone` 後に bootstrap (`.config/yadm/bootstrap`) が実行され、`mise install` が走る。
自動実行されない場合は手動で:

```sh
yadm bootstrap
```

## 管理対象

| ファイル | 用途 |
| --- | --- |
| `.gitconfig` | git 設定 |
| `.config/zed/{settings,keymap}.json` | Zed エディタ |
| `.config/mise/config.toml` | mise（ツールバージョン管理） |
| `.config/karabiner/karabiner.json` | Karabiner-Elements（macOS） |
| `.config/yadm/bootstrap` | clone 後のセットアップスクリプト |

## よく使う操作

```sh
yadm status            # 変更確認
yadm add <file>        # 追跡に追加
yadm commit -m "..."   # コミット
yadm push              # リモートへ反映
yadm list -a           # 管理対象ファイル一覧
```
