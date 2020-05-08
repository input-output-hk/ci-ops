with { pkgs = import ../../nix { }; };
pkgs.mkShell {
  buildInputs = with pkgs; [
    crystal_0_33
    crystal2nix
    niv
    jq
    shards
    pkg-config
    openssl
  ];
}
