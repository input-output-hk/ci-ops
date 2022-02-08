{ callPackage }:
let
  inherit (builtins) typeOf trace attrNames toString;
  sources = import ./sources.nix;
  self = builtins.getFlake (toString ./..);
in {
  cachecache = self.inputs.cachecache.packages.x86_64-linux.cachecache;
  crystalPkgs = callPackage ../pkgs/hydra-crystal-notify {};
  hydra = self.inputs.hydra.outputs.packages.x86_64-linux.hydra;
  nix = self.inputs.hydra.inputs.nix.defaultPackage.x86_64-linux;
  pp = v:
    let type = typeOf v;
    in if type == "list" then
      trace (toString v) v
    else if type == "set" then
      trace (toString (attrNames v)) v
    else
      trace (toString v) v;
}
