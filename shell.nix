with { pkgs = import ./nix { }; };
pkgs.mkShell {
  buildInputs = with pkgs; [ niv nixops cacert ];
  NIX_PATH = "nixpkgs=${pkgs.path}";
}
