{ pkgs }:

let
  sources = import ../nix/sources.nix;

  # Migration route from hydra legacy (19.03) to master:
  # Rough outline at: https://github.com/NixOS/hydra/issues/725

  # Step 0 -- At legacy (migration tested locally from this pin)
  #
  #hydraSrc = sources.hydra-legacy;
  #hydraNixpkgs = pkgs;
  #hydraPatches = [
  #  (pkgs.fetchpatch {
  #    url = "https://github.com/NixOS/hydra/pull/648/commits/4171ab4c4fd576c516dc03ba64d1c7945f769af0.patch";
  #    sha256 = "1fxa2459kdws6qc419dv4084c1ssmys7kqg4ic7n643kybamsgrx";
  #  })
  #];

  # Step 1 -- Move to rev add4f6 upstream
  #
  #hydraSrc = sources.hydra-migrate-step-1;
  #hydraNixpkgs = import sources.hydra-migrate-nixpkgs-step-1 { };
  #hydraPatches = [ ];

  # Step 2 -- Final commit; move to upstream master + IOHK customization cherry picks
  #
  hydraSrc = sources.hydra;
  hydraNixpkgs = import sources.hydra-nixpkgs { };
  hydraPatches = [ ];
in
  hydraNixpkgs.callPackage ./hydra-fork.nix {
    nixpkgsPath = hydraNixpkgs.path;
    patches = hydraPatches;
    src = hydraSrc;
  }
