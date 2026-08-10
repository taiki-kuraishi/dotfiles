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
    # trusted = true で brew trust 相当を activation 時に自動適用する
    taps = [
      {
        name = "abue-ammar/tinycast";
        trusted = true;
      }
    ];
    # bitwarden-cli は bitwarden(GUI, 下記cask)と揃えるため brew で管理する。
    brews = [ "bitwarden-cli" ];
    # ghostty は nixpkgs の darwin ビルドが unavailable のため cask で導入する。
    # bitwarden は nixpkgs 版が ad-hoc 署名のため、macOS の SSH Agent 拡張機能への
    # 登録ができない（公式署名済みビルドが必要）ため cask で導入する。
    # karabiner-elements は仮想HIDデバイスドライバー（システム拡張）の承認が必要なため、
    # 公式の署名済みビルドを使う cask で導入する。
    # stats は brew cask 版が自動更新に対応しているため cask で導入する。
    casks = [
      "ghostty"
      "tinycast"
      "bitwarden"
      "karabiner-elements"
      "stats"
      "orbstack"
    ];
  };
}
