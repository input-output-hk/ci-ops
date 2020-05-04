with { pkgs = import ./nix { }; };
pkgs.mkShell {
  buildInputs = with pkgs; [
    crystal
    crystal2nix
    niv
    jq
    shards
    pkg-config
    openssl
  ];
}
