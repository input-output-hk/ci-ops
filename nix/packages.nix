{ callPackage }:
let
  inherit (builtins) typeOf trace attrNames toString;
  sources = import ./sources.nix;
in {
  cachecache = callPackage (sources.cachecache) {};
  crystalPkgs = callPackage ../pkgs/hydra-crystal-notify {};
  pp = v:
    let type = typeOf v;
    in if type == "list" then
      trace (toString v) v
    else if type == "set" then
      trace (toString (attrNames v)) v
    else
      trace (toString v) v;
}
