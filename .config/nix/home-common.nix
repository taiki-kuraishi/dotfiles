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
    # レビュー向けターミナル diff ビューア（nixpkgs 未収録。flake.nix の overlay 経由）
    hunk
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
    ++ [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.bun/bin"
    ]
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

  # programs.zsh が生成する .zshrc / .zprofile は HM 管理外の既存ファイルと衝突しやすい。
  # かつては home.file.".zshrc".force = true; で個別に強制上書きしていたが、
  # home-manager の zsh モジュール側のバグ（dotDir がホームディレクトリと同じ場合、
  # 内部で home.file キーが "./.zshrc" になり ".zshrc" とマージされない。
  # nix-community/home-manager commit 5432dc5bc4a0 で混入、2026-07 時点で master でも未修正）
  # により force が効かず home-manager.users.<user>.home.file.".zshrc".source が
  # 未定義のまま参照されて評価エラーになっていた。
  # 衝突時の強制上書きは個別ファイルではなく darwin-configuration.nix /
  # flake.nix 側の home-manager.backupFileExtension で一括対応する
  # （内部キー名に依存しないため upstream のこのバグの影響を受けない）。
}
