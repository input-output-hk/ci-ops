with import ./nix { };
mkShell {
  nativeBuildInputs = [ niv nixUnstable nixops cacert direnv nix-direnv lorri];
  NIX_PATH = "nixpkgs=${path}";
}
