{
  hostName,
  username,
  ...
}:
{
  nix.settings.experimental-features = "nix-command flakes";
  nixpkgs.config.allowUnfree = true;

  programs.zsh.enable = true;

  system.stateVersion = 5;
  networking.hostName = hostName;
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  system.defaults = {
    dock = {
      static-only = true;
    };
  };

  homebrew = {
    enable = true;
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    taps = [
      {
        name = "abue-ammar/tinycast";
        trusted = true;
      }
      {
        name = "FelixKratz/formulae";
        trusted = true;
      }
    ];
    brews = [
      "bitwarden-cli"
      "tailscale"
      "sketchybar"
    ];
    casks = [
      "ghostty"
      "tinycast"
      "bitwarden"
      "karabiner-elements"
      "stats"
      "orbstack"
      "tailscale-app"
      "font-sketchybar-app-font"
      "font-hackgen-nerd"
      {
        name = "nikitabobko/tap/aerospace";
        trusted = true;
      }
    ];
  };
}
