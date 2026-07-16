{
  description = "Kuraishi's Nix config (nix-darwin + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # hunk（modem-dev/hunk）は nixpkgs 未収録のため upstream flake の default
    # パッケージを取り込む。nixpkgs は follows で本 flake のものに揃える。
    hunk.url = "github:modem-dev/hunk";
    hunk.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      hunk,
    }:
    let
      # ホスト固有の値（ユーザー名・ホスト名）はここだけに集約する。
      # 設定本体（darwin-configuration.nix / home-common.nix）はジェネリックに保つ。

      # nixpkgs 未収録のパッケージを pkgs.<name> として参照できるようにする overlay。
      # macOS（mkSystem）/ Linux（mkHome）双方に配線し、home-common.nix からは
      # 由来を意識せず `hunk` として使えるようにする。
      overlays = [
        (final: prev: {
          hunk = hunk.packages.${prev.stdenv.hostPlatform.system}.default;
        })
      ];

      # macOS: nix-darwin システム + Home Manager 統合
      mkSystem =
        { hostName, username }:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit hostName username; };
          modules = [
            { nixpkgs.overlays = overlays; }
            ./darwin-configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit hostName username; };
              home-manager.users.${username} = import ./home-common.nix;
              # HM 管理外の既存ファイル（初回の .zshrc / .zprofile 等）と衝突した場合、
              # activation を失敗させず *.backup に退避して上書きする。
              # 個別ファイルの home.file.<name>.force ではなくこちらで一括対応する理由は
              # home-common.nix のコメントを参照。
              home-manager.backupFileExtension = "backup";
              # 2 回目以降の bootstrap で *.backup が既に存在していても失敗させない。
              home-manager.overwriteBackup = true;
            }
          ];
        };

      # Linux: standalone Home Manager（roppoh Pod / CI）
      mkHome =
        { username, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system overlays;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit username; };
          modules = [
            ./home-common.nix
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
            }
          ];
        };
    in
    {
      darwinConfigurations = {
        "macbook-air" = mkSystem {
          hostName = "macbook-air";
          username = "kuraishi";
        };
        "RN2162" = mkSystem {
          hostName = "RN2162";
          username = "t_kuraishi";
        };
        # GitHub Actions ランナー用（bootstrap 検証 CI）。実ユーザー runner に合わせる。
        "ci-runner" = mkSystem {
          hostName = "ci-runner";
          username = "runner";
        };
      };

      # Linux（roppoh Pod / GitHub Actions linux job）。
      # 名前は <user>-<system> でアーキを区別し、bootstrap が uname -m で選択する。
      homeConfigurations = {
        "user-x86_64-linux" = mkHome {
          username = "user";
          system = "x86_64-linux";
        };
        "user-aarch64-linux" = mkHome {
          username = "user";
          system = "aarch64-linux";
        };
        "runner-x86_64-linux" = mkHome {
          username = "runner";
          system = "x86_64-linux";
        };
      };

      # nix fmt で nixfmt（公式フォーマッタ）が走るようにする
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
