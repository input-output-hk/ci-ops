{ sources ? import ./sources.nix, system ? __currentSystem }:
with {
  overlay = _: pkgs: {
    inherit (import sources.niv { }) niv;
    packages = pkgs.callPackages ./packages.nix { };
  };
};
import sources.nixpkgs {
  overlays = [ overlay ];
  inherit system;
  config = { };
}
