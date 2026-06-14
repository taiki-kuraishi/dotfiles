{ pkgs, ... }: {
  nix.settings.experimental-features = "nix-command flakes";
  environment.systemPackages = [ pkgs.vim pkgs.starship pkgs.git ];
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
  system.stateVersion = 5;
  networking.hostName = "macbook-air";
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = "kuraishi";

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
    ];
    brews = [
      "mise"
      "gh"
      "ghq"
      "yadm"
    ];
  };
}
