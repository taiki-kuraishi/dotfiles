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

    # bun / npm / pnpm の補完（mise でツールが PATH に入った後に生成）
    # pnpm は compdef を使うため、先に補完システムを初期化しておく
    autoload -Uz compinit && compinit
    command -v npm  >/dev/null && source <(npm completion)
    command -v pnpm >/dev/null && source <(pnpm completion zsh)
    command -v bun  >/dev/null && source <(bun completions)
  '';

  # 環境変数
  environment.variables = {
    # sops が使う age 復号鍵のパス（age のデフォルト保存先）
    SOPS_AGE_KEYFILE = "$HOME/.config/sops/age/keys.txt";
  };

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
      "orbstack"
    ];
    brews = [
      "mise"
      "gh"
      "ghq"
      "yadm"
      "cloudflared"
    ];
  };
}
