with import <nixpkgs> {};

pkgs.stdenv.mkDerivation rec {
  name = "env";

  buildInputs = [
  ] ++ (with pkgs; [
  ]);

  nativeBuildInputs = with pkgs; [
    crystal
    shards
  ];
}
