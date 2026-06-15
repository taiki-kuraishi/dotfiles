{
  pkgs,
  hostName,
  username,
  ...
}:
{
  nix.settings.experimental-features = "nix-command flakes";
  environment.systemPackages = [
    pkgs.vim
    pkgs.starship
    pkgs.git
    pkgs.nixfmt
    pkgs.dprint
  ];
  programs.zsh.enable = true;
  programs.zsh.promptInit = ''
    eval "$(starship init zsh)"
  '';
  programs.zsh.shellInit = ''
    export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
    fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
  '';
  programs.zsh.interactiveShellInit = ''
    eval "$(mise activate zsh)"
  '';

  # シェルエイリアス（bash/zsh 共通）
  environment.shellAliases = {
    g = "git";
    do = "docker";
    doc = "docker compose";
    mtr = "mise tasks run";
  };

  system.stateVersion = 5;
  networking.hostName = hostName;
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = username;

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
  # Homebrew 連携設定
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
    brews = [
      "mise"
      "gh"
      "ghq"
      "yadm"
    ];
  };
}
