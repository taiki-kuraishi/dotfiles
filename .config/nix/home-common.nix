# 共有 Home Manager モジュール（macOS / Linux 共通のユーザー環境の単一情報源）。
#   macOS : nix-darwin の home-manager.darwinModules 経由で適用
#   Linux : standalone homeConfigurations 経由で適用
# OS 差分は lib.mkIf / lib.optionals / lib.optionalString で分岐する。
# 注: gh / mise の設定ファイル（~/.config/gh/config.yml, ~/.config/mise/config.toml）は
#     yadm 管理下のため、HM の programs.gh / programs.mise では管理しない
#     （バイナリだけ home.packages で入れ、activate は zsh initContent で行う）。
{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.stateVersion = "25.05";

  # ユーザーパッケージ（両 OS 共通）
  home.packages = with pkgs; [
    neovim
    git
    nixfmt
    dprint
    nixd
    cloudflared
    mise
    gh
    ripgrep
    fd
    fzf
    lazygit
    tree-sitter
    tmux
    ghq
    # docker CLI クライアント。デーモンは nix/HM では管理せず外部が提供する
    # （macOS: OrbStack / Dory 等、Linux: Pod 側）。
    docker
    kubectl
    # roppoh Pod の Dockerfile から移設。mise が入れる node/bun 等のネイティブビルド
    # （例: better-sqlite3 の node-gyp フォールバック）用の最低限のツールチェイン。
    gcc
    gnumake
    python3
  ];

  # 環境変数
  home.sessionVariables = {
    # sops が使う age 復号鍵のパス（age のデフォルト保存先）
    SOPS_AGE_KEYFILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    GOOGLE_CLOUD_PROJECT = "gen-lang-client-0186675745";
  };

  # PATH（.local/bin は共通。opencode / homebrew は macOS のみ）
  home.sessionPath =
    lib.optionals pkgs.stdenv.isDarwin [ "${config.home.homeDirectory}/.opencode/bin" ]
    ++ [ "${config.home.homeDirectory}/.local/bin" ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ "/opt/homebrew/bin" ];

  # プロンプト（starship は yadm 管理の設定が無いので HM に任せてよい）
  programs.starship.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      g = "git";
      do = "docker";
      doc = "docker compose";
      mtr = "mise tasks run";
    };

    # 既定順（order 1000 = compinit 後。旧 initExtra 相当）
    initContent = ''
      # mise アクティベート（ツールは ~/.config/mise/config.toml + `mise install` で管理）
      command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
      command -v task >/dev/null 2>&1 && eval "$(task --completion zsh)"

      # bun / npm / pnpm の補完（mise でツールが PATH に入った後に読み込む）
      command -v npm  >/dev/null && source <(npm completion)
      command -v pnpm >/dev/null && source <(pnpm completion zsh)
      command -v bun  >/dev/null && source <(bun completions)
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''

      # OrbStack: command-line tools and integration（macOS のみ）
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    ''
    + lib.optionalString pkgs.stdenv.isLinux ''

      # gh を GitHub App の短命トークンで動かす（gh-app-token は Pod にのみ存在）
      if command -v gh-app-token >/dev/null 2>&1; then
        gh() { GH_TOKEN="$(gh-app-token)" command gh "$@"; }
      fi
    '';
  };
}
