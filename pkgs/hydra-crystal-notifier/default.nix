{ callPackage
, gitignoreSource
, crystal_0_33
, lib
, openssl
, curl
, zlib
, pkg-config
}:

let
  filter = name: type: let
    baseName = baseNameOf (toString name);
    sansPrefix = lib.removePrefix (toString ../.) name;
  in (
    baseName == "src" ||
    lib.hasSuffix ".cr" baseName
  );
in {
  hydra-crystal-notifier = crystal_0_33.buildCrystalPackage {
    pname = "hydra-crystal-notifier";
    version = "0.1.0";
    #src = lib.cleanSourceWith {
    #  inherit filter;
    #  src = ./.;
    #  name = "hydra-crystal-notifier";
    #};
    src = gitignoreSource ./.;
    crystalBinaries."hydra-crystal-notifier".src = "src/hydra-crystal-notifier.cr";
    shardsFile = ./shards.nix;
    buildInputs = [];
    doCheck = true;
  };
}
