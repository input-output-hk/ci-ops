{ callPackage }:
let
  inherit (builtins) typeOf trace attrNames toString;
  inherit (import sources.gitignore { }) gitignoreSource;
  sources = import ./sources.nix;
in {
  cachecache = callPackage (sources.cachecache) {};
  hydra-crystal-notifier = callPackage ../pkgs/hydra-crystal-notifier {};
  pp = v:
    let type = typeOf v;
    in if type == "list" then
      trace (toString v) v
    else if type == "set" then
      trace (toString (attrNames v)) v
    else
      trace (toString v) v;
}
