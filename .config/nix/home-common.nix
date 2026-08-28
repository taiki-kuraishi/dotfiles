{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.stateVersion = "25.05";

  home.packages =
    with pkgs;
    [
      neovim
      git
      nixfmt
      dprint
      nixd
      cloudflared
      mise
      gh
      jq
      jaq
      less
      ripgrep
      fd
      fzf
      lazygit
      tree-sitter
      tmux
      ghq
      hunk
      docker
      kubectl
      gnumake
      pkg-config
      python3
    ]
    ++ lib.optionals stdenv.isLinux [
      gcc
      fuse-overlayfs
    ];

  home.sessionVariables = {
    SOPS_AGE_KEYFILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    GOOGLE_CLOUD_PROJECT = "gen-lang-client-0186675745";
  };

  home.sessionPath =
    lib.optionals pkgs.stdenv.isDarwin [ "${config.home.homeDirectory}/.opencode/bin" ]
    ++ [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.bun/bin"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ "/opt/homebrew/bin" ];

  programs.starship.enable = true;

  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };

  programs.bat.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      g = "git";
      do = "docker";
      doc = "docker compose";
      mtr = "mise tasks run";
      cat = "bat --paging=never";
      jq = "jaq";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
    };

    initContent = ''
      command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
      command -v task >/dev/null 2>&1 && eval "$(task --completion zsh)"
      command -v wt   >/dev/null 2>&1 && eval "$(command wt config shell init zsh)"

      command -v npm  >/dev/null && source <(npm completion)
      command -v pnpm >/dev/null && source <(pnpm completion zsh)
      command -v bun  >/dev/null && source <(bun completions)

      gh() {
        local url org u
        url=$(command git config --get remote.origin.url 2>/dev/null)
        org=$(basename "$(dirname "$url")")
        case "$org" in
          fancomi-interconnect|a8-engineer|fancs-product-mgmt|t-kuraishi_fancs) u="t-kuraishi_fancs" ;;
          *)                                                 u="taiki-kuraishi"   ;;
        esac
        GH_TOKEN="$(command gh auth token --user "$u" 2>/dev/null)" command gh "$@"
      }
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''

      source ~/.orbstack/shell/init.zsh 2>/dev/null || :

      [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ] \
        && source <("/Applications/Tailscale.app/Contents/MacOS/Tailscale" completion zsh)
    ''
    + lib.optionalString pkgs.stdenv.isLinux ''

      if command -v gh-app-token >/dev/null 2>&1; then
        gh() { GH_TOKEN="$(gh-app-token)" command gh "$@"; }
      fi
    '';
  };

}
