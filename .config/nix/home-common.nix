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
      # レビュー向けターミナル diff ビューア（nixpkgs 未収録。flake.nix の overlay 経由）
      hunk
      # docker CLI クライアント。デーモンは nix/HM では管理しない
      # （macOS: OrbStack / Dory 等が外部提供。Linux: Pod 側が提供、
      #   それが無い一般ディストリでは bootstrap##os.Linux が導入する）。
      docker
      kubectl
      # roppoh Pod の Dockerfile から移設。mise が入れる node/bun 等のネイティブビルド
      # （例: better-sqlite3 の node-gyp フォールバック）用の最低限のツールチェイン。
      gnumake
      pkg-config
      python3
    ]
    ++ lib.optionals stdenv.isLinux [
      # C コンパイラは Linux のみ nix から入れる。macOS は Xcode CLT が
      # /usr/bin/{cc,gcc,clang}（Apple clang）を提供済みで、nix の gcc を入れると
      # PATH 上で cc を覆い、macOS SDK の libiconv 等を解決できずリンクが壊れる
      # （例: cargo build が `ld: library not found for -liconv` で落ちる）。
      gcc
      # roppoh dev-pod: dockerd の overlay2 が Pod 内では使えない（overlay-on-overlay を
      # カーネルが拒否）ため fuse-overlayfs で代替。無ければ vfs にフォールバックする想定。
      fuse-overlayfs
    ]
    ++ lib.optionals stdenv.isDarwin [
      # GUI アプリのため macOS のみ。Linux 側（roppoh Pod / CI）は headless なので入れない。
      zed-editor
    ];

  # 環境変数
  home.sessionVariables = {
    # sops が使う age 復号鍵のパス（age のデフォルト保存先）
    SOPS_AGE_KEYFILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    GOOGLE_CLOUD_PROJECT = "gen-lang-client-0186675745";
    # claude code のマウスキャプチャを無効化し、ターミナル本来のテキスト選択を使えるようにする
    CLAUDE_CODE_DISABLE_MOUSE = "1";
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

  # cd を zoxide 化（--cmd cd で cd 自体を置き換え、通常の cd としても動く）
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };

  # cat のシンタックスハイライト版。設定ファイルは持たない（yadm 管理外）
  programs.bat.enable = true;

  programs.zsh = {
    enable = true;

    shellAliases = {
      g = "git";
      do = "docker";
      doc = "docker compose";
      mtr = "mise tasks run";
      # 対話シェルのみに効く。statusline-command.sh 等の非対話実行は
      # 実体の jq/cat バイナリを直接使うため影響を受けない
      cat = "bat --paging=never";
      jq = "jaq";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # Tailscale.app 同梱の CLI（Homebrew 版と違い GUI 連携込みで動く）を使う
      tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
    };

    # 既定順（order 1000 = compinit 後。旧 initExtra 相当）
    initContent = ''
      # mise アクティベート（ツールは ~/.config/mise/config.toml + `mise install` で管理）
      command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
      command -v task >/dev/null 2>&1 && eval "$(task --completion zsh)"
      command -v wt   >/dev/null 2>&1 && eval "$(command wt config shell init zsh)"

      # bun / npm / pnpm の補完（mise でツールが PATH に入った後に読み込む）
      command -v npm  >/dev/null && source <(npm completion)
      command -v pnpm >/dev/null && source <(pnpm completion zsh)
      command -v bun  >/dev/null && source <(bun completions)
    ''
    + lib.optionalString pkgs.stdenv.isDarwin ''

      # OrbStack: command-line tools and integration（macOS のみ）
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :

      # Tailscale.app 同梱 CLI の zsh 補完（alias 経由で PATH 上に無いため実体パスで判定）
      [ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ] \
        && source <("/Applications/Tailscale.app/Contents/MacOS/Tailscale" completion zsh)

      # gh を「リポジトリの org」に応じたアカウントで動かす（macOS のみ）。
      gh() {
        local url org u
        url=$(command git config --get remote.origin.url 2>/dev/null)
        org=$(basename "$(dirname "$url")")
        case "$org" in
          fancomi-interconnect|a8-engineer|t-kuraishi_fancs) u="t-kuraishi_fancs" ;;
          *)                                                 u="taiki-kuraishi"   ;;
        esac
        GH_TOKEN="$(command gh auth token --user "$u" 2>/dev/null)" command gh "$@"
      }
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
