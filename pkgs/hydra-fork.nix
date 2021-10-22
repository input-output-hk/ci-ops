{ fetchFromGitHub, nixpkgsPath, src, patches, overlays }:

let
  hydraRelease = (import (src + "/release.nix") {
    nixpkgs = nixpkgsPath;
    inherit overlays;
    hydraSrc = {
      outPath = src;
      rev = builtins.substring 0 6 src.rev;
      revCount = 1234;
    };
  });

in
  hydraRelease.build.x86_64-linux.overrideAttrs (drv: { inherit patches; })
