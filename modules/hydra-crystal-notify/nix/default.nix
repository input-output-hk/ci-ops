{ sources ? import ./sources.nix }:
with {
  overlay = self: super: {
    inherit (import sources.niv { }) niv;
    inherit (import sources.nixpkgs-crystal { }) crystal2nix shards;
    crystal = (import sources.nixpkgs-crystal { }).crystal.overrideAttrs(_: { doCheck = false; });
    packages = self.callPackages ./packages.nix { };
    inherit (import sources.gitignore { inherit (self) lib; }) gitignoreSource;
  };
};
import sources.nixpkgs {
  overlays = [ overlay ];
  config = { };
}
