with import ./nix { };
mkShell {
  nativeBuildInputs = [ niv packages.nix nixops cacert direnv nix-direnv lorri];
  NIX_PATH = "nixpkgs=${path}";
}
