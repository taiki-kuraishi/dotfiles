{
  description = "Kuraishi's Mac Darwin system flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
    }:
    {
      darwinConfigurations."macbook-air" = nix-darwin.lib.darwinSystem {
        modules = [ ./darwin-configuration.nix ];
      };

      # nix fmt で nixfmt（公式フォーマッタ）が走るようにする
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
