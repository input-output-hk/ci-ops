{ pkgs, config, lib, ... }:
let
  cfg = config.services.nix-version;
  inherit (lib) types mkIf mkOption;
in {
  options = {
    services.nix-version = {
      flakeRef = mkOption {
        type = types.str;
        default = null;
        description = "The github:NixOS/nix flake reference to use for the nix package";
      };

      package = mkOption {
        type = types.package;
        default = (builtins.getFlake cfg.flakeRef).packages.x86_64-darwin.nix;
        description = "The github:NixOS/nix package to use for the nix package";
      };
    };
  };
}
