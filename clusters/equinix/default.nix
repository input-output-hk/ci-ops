with import <nixpkgs> {};

let
  hosts = lib.attrNames (lib.filterAttrs (k: v: v == "directory") (builtins.readDir ./.));
in lib.listToAttrs (map (name: { inherit name; value = import (./. + ("/" + name)); }) hosts)
