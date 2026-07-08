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
  # Homebrew 連携設定（GUI casks のみ。CLI ツールは Home Manager(nix) 側で管理）
  # ---------------------------------------------------------------------
  homebrew = {
    enable = true;
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    casks = [
      "google-chrome"
      "zed"
      "raycast"
    ];
    # yadm は bootstrap の前提（先に存在する必要がある）ため Homebrew 管理のまま残す。
    brews = [
      "yadm"
    ];
  };
}
