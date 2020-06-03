{ sources ? import ./sources.nix, system ? __currentSystem }:
let
  crystalPkgs = import sources.nixpkgs-crystal {};
in with {
  overlay = self: super: {
    inherit (import sources.niv { }) niv;
    inherit (crystalPkgs) crystal2nix jq shards openssl pkg-config;
    crystal = crystalPkgs.crystal_0_34;
    packages = self.callPackages ./packages.nix { };
    globals = import ../globals.nix;

    nixops = (import (sources.nixops-core + "/release.nix") {
      nixpkgs = super.path;
      p = (p:
        let
          pluginSources = with sources; [ nixops-packet nixops-libvirtd ];
          plugins = map (source: p.callPackage (source + "/release.nix") { })
            pluginSources;
        in [ p.aws ] ++ plugins);
    }).build.${system};
  };
};
import sources.nixpkgs {
  overlays = [ overlay ];
  inherit system;
  config = { };
}
