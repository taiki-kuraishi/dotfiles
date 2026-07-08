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
    let
      # ホスト固有の値（ユーザー名・ホスト名）はここだけに集約する。
      # 設定本体（darwin-configuration.nix）はジェネリックに保つ。
      mkSystem =
        { hostName, username }:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit hostName username; };
          modules = [ ./darwin-configuration.nix ];
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

      # nix fmt で nixfmt（公式フォーマッタ）が走るようにする
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    };
}
