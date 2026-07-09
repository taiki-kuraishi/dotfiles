{
  description = "Kuraishi's Nix config (nix-darwin + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
    }:
    let
      # ホスト固有の値（ユーザー名・ホスト名）はここだけに集約する。
      # 設定本体（darwin-configuration.nix / home-common.nix）はジェネリックに保つ。

      # macOS: nix-darwin システム + Home Manager 統合
      mkSystem =
        { hostName, username }:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit hostName username; };
          modules = [
            ./darwin-configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit hostName username; };
              home-manager.users.${username} = import ./home-common.nix;
            }
          ];
        };

      # Linux: standalone Home Manager（roppoh Pod / CI）
      mkHome =
        { username, system }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
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
        "claude-x86_64-linux" = mkHome {
          username = "claude";
          system = "x86_64-linux";
        };
        "claude-aarch64-linux" = mkHome {
          username = "claude";
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
