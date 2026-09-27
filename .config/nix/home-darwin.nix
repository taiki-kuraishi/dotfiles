# Darwin (nix-darwin + Home Manager) 固有の設定。home-common.nix から OS 依存の分岐を移設した。
{ config, lib, ... }:

lib.mkMerge [
  # ~/.opencode/bin は共通エントリより前に、/opt/homebrew/bin は後ろに置く。
  # 同一優先度の定義は順序が不定になるため mkBefore / mkAfter で明示する。
  {
    home.sessionPath = lib.mkBefore [ "${config.home.homeDirectory}/.opencode/bin" ];
  }
  {
    home.sessionPath = lib.mkAfter [ "/opt/homebrew/bin" ];
  }
  {
    programs.zsh.shellAliases.tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";

    programs.zsh.initContent = lib.mkAfter ''
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :

      [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ] \
        && source <("/Applications/Tailscale.app/Contents/MacOS/Tailscale" completion zsh)
    '';
  }
]
