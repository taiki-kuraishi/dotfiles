{
  description = "Kuraishi's Nix config (nix-darwin + Home Manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hunk.url = "github:modem-dev/hunk";
    hunk.inputs.nixpkgs.follows = "nixpkgs";
    bun2nix.url = "github:nix-community/bun2nix";
    bun2nix.inputs.nixpkgs.follows = "nixpkgs";
    hunk.inputs.bun2nix.follows = "bun2nix";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      hunk,
      ...
    }:
    let

      overlays = [
        (final: prev: {
          hunk = hunk.packages.${prev.stdenv.hostPlatform.system}.default;
        })
      ];

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
              home-manager.backupFileExtension = "backup";
              home-manager.overwriteBackup = true;
            }
          ];
        };

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
        "AC0116" = mkSystem {
          hostName = "AC0116";
          username = "t_kuraishi";
        };
        "ci-runner" = mkSystem {
          hostName = "ci-runner";
          username = "runner";
        };
      };

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

      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
