{ system ? builtins.currentSystem
, config ? { }
}:
let
  sources = import ./sources.nix { inherit pkgs; };

  overlay = self: super: {
    crystal = self.crystal_0_34;
    packages = self.callPackages ./packages.nix { };
    systemd-exporter = self.callPackage ../pkgs/systemd_exporter { };
    globals = import ../globals.nix;

    nixops = (import (sources.nixops-core + "/release.nix") {
      nixpkgs = super.path;
      p = (p:
        let
          pluginSources = with sources; [
            nixops-packet
            # python2 libvirtd is flagged as insecure in nixpkgs
            #nixops-libvirtd
          ];
          plugins = map (source: p.callPackage (source + "/release.nix") { })
            pluginSources;
        in
        [ p.aws ] ++ plugins);
    }).build.${system};
  };

  pkgs = import sources.nixpkgs {
    overlays = [ overlay ];
    inherit system config;
  };

in
pkgs
