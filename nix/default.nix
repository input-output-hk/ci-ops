{ sources ? import ./sources.nix, system ? __currentSystem }:
with {
  overlay = self: super: {
    inherit (import sources.niv { }) niv;
    inherit (import sources.nixpkgs-crystal {}) crystal_0_33 crystal2nix jq shards openssl curl pkg-config zlib;
    inherit (import sources.gitignore { inherit (self) lib; }) gitignoreSource;
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
