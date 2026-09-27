{
  config,
  pkgs,
  ...
}:
let
  # gh は CLICOLOR_FORCE を尊重して JSON 出力にも ANSI を付けるため、パイプで JSON を読む
  # ツール（tuicr / jq など）が壊れる。gh 自身には色を強制させない。
  # symlinkJoin はキャッシュ済みバイナリを再利用する（overrideAttrs だと gh を再ビルドする）。
  # 限界: 効くのは home.packages 経由の gh のみ。mise.toml の CLICOLOR_FORCE は残るため
  # nix run / brew / コンテナ内の gh は色付きのまま。unset は gh の子プロセスにも波及する。
  ghUncolored = pkgs.symlinkJoin {
    name = "gh-uncolored";
    paths = [ pkgs.gh ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = "wrapProgram $out/bin/gh --unset CLICOLOR_FORCE --unset FORCE_COLOR";
  };
in
{
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    neovim
    git
    nixfmt
    dprint
    nixd
    cloudflared
    mise
    ghUncolored
    jq
    jaq
    less
    glow
    ripgrep
    fd
    fzf
    lazygit
    tree-sitter
    tmux
    ghq
    hunk
    tuicr
    docker
    kubectl
    keycloak # provides bin/kcadm.sh, bin/kcreg.sh (no standalone CLI exists)
    gnumake
    pkg-config
    python3
  ];

  home.sessionVariables = {
    SOPS_AGE_KEYFILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    GOOGLE_CLOUD_PROJECT = "gen-lang-client-0186675745";
    # Pin the Claude Code install; claude auto-update deletes the versioned
    # binary pi-claude-code-provider has spawned (ENOENT / protocol drift).
    DISABLE_AUTOUPDATER = "1";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.nix-profile/bin"
  ];

  programs.starship.enable = true;

  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };

  programs.bat.enable = true;

  programs.direnv.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      g = "git";
      do = "docker";
      doc = "docker compose";
      mtr = "mise tasks run";
      cat = "bat --paging=never";
      jq = "jaq";
      keycloak = "kcadm.sh";
    };

    initContent = ''
      command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
      command -v task >/dev/null 2>&1 && eval "$(task --completion zsh)"
      command -v wt   >/dev/null 2>&1 && eval "$(command wt config shell init zsh)"

      command -v npm  >/dev/null && source <(npm completion)
      command -v pnpm >/dev/null && source <(pnpm completion zsh)
      command -v bun  >/dev/null && source <(bun completions)
      command -v gh   >/dev/null && eval "$(command gh completion -s zsh)"
    '';
  };

}
