{ pkgs }:

let
  sources = import ../nix/sources.nix;

  hydraSrc = sources.hydra;
  hydraNixpkgs = import sources.hydra-nixpkgs { };
  hydraPatches = [ ];
in
  hydraNixpkgs.callPackage ./hydra-fork.nix {
    nixpkgsPath = hydraNixpkgs.path;
    patches = hydraPatches;
    src = hydraSrc;
  }
