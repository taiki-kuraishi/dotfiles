{
  hostName,
  username,
  ...
}:
{
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;

  # zsh はシステム側でも有効化。ユーザー設定（プロンプト/PATH/補完/エイリアス/環境変数）は
  # Home Manager（home-common.nix）が一元管理する。
  programs.zsh.enable = true;

  system.stateVersion = 5;
  networking.hostName = hostName;
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = username;

  # Home Manager がユーザーの home ディレクトリを解決できるように宣言する。
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # ---------------------------------------------------------------------
  # macOS のシステム設定（defaults write の代わり）
  # ---------------------------------------------------------------------
  system.defaults = {
    dock = {
      # 起動中のアプリケーションのみをDockに表示する
      static-only = true;
    };
  };

  # ---------------------------------------------------------------------
  # Homebrew 連携設定（GUI casks が中心。CLI ツールは基本 Home Manager(nix) 側で管理するが、
  # 公式署名済みビルドが必要なものはこちらで管理する）
  # ---------------------------------------------------------------------
  homebrew = {
    enable = true;
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    # サードパーティ tap（tinycast は nixpkgs 未収録のため cask 経由で導入）
    # FelixKratz/formulae は sketchybar(下記brew)の配布元 tap のため追加する。
    # trusted = true で brew trust 相当を activation 時に自動適用する
    taps = [
      {
        name = "abue-ammar/tinycast";
        trusted = true;
      }
      {
        name = "FelixKratz/formulae";
        trusted = true;
      }
    ];
    # bitwarden-cli は bitwarden(GUI, 下記cask)と揃えるため brew で管理する。
    # tailscale は PATH の通った CLI を使うため formula も入れる（デーモンは GUI 側を使う）。
    # sketchybar は上記 FelixKratz/formulae tap 経由で導入する menu bar ツール。
    brews = [
      "bitwarden-cli"
      "tailscale"
      "sketchybar"
    ];
    # ghostty は nixpkgs の darwin ビルドが unavailable のため cask で導入する。
    # bitwarden は nixpkgs 版が ad-hoc 署名のため、macOS の SSH Agent 拡張機能への
    # 登録ができない（公式署名済みビルドが必要）ため cask で導入する。
    # karabiner-elements は仮想HIDデバイスドライバー（システム拡張）の承認が必要なため、
    # 公式の署名済みビルドを使う cask で導入する。
    # stats は brew cask 版が自動更新に対応しているため cask で導入する。
    # tailscale-app は VPN のシステム拡張の承認が必要なため、公式の署名済みビルドを
    # 使う cask で導入する（cask 名は tailscale からリネーム済み）。
    # aerospace は nixpkgs 未収録のため公式 tap 埋め込みのフルネームで cask 導入する
    # （tap を別途宣言しないため、cask 側で trusted = true が必要）。
    # font-sketchybar-app-font は SketchyBar のワークスペースitemにアプリアイコンを
    # 表示するための専用フォント（homebrew-cask 公式 tap 収録のため trusted 不要）。
    # thaw はメニューバーアイコンの整理用。jordanbaird-ice(Ice)は macOS 26 で
    # NSStatusBarWindow 周りが頻繁にクラッシュするため、同じ Ice 系統で macOS 26/27
    # 対応を謳う OSS フォークの thaw に乗り換えた（同様に公式 tap 収録）。
    casks = [
      "ghostty"
      "tinycast"
      "bitwarden"
      "karabiner-elements"
      "stats"
      "orbstack"
      "tailscale-app"
      "font-sketchybar-app-font"
      "thaw"
      {
        name = "nikitabobko/tap/aerospace";
        trusted = true;
      }
    ];
  };
}
