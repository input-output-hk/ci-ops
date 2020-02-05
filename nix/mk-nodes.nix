{ targetEnv }:
let
  inherit (import ../nix { }) lib;
  inherit (lib)
    range listToAttrs mapAttrsToList nameValuePair foldl forEach filterAttrs
    recursiveUpdate;

  globals = import ../globals.nix;

  # defs: passed from clusters/$NIXOPS-DEPLOYMENT.nix as the node defs
  mkNodes = defs:
    listToAttrs (foldl foldNodes {
      nodes = [ ];
    } (mapAttrsToList definitionToNode defs)).nodes;

  # Add additonal logic here in the future if needed
  foldNodes = { nodes }: elem: {
      nodes = nodes ++ [ elem ];
    };

  mkNode = name: args:
    recursiveUpdate {
      require = [ ../modules/common.nix ../modules/wireguard.nix ];
      deployment = {
        targetEnv = targetEnv;
        targetHost = name + "." + globals.domain;
      };
      _module.args = { inherit globals; };
    } args;

  definitionToNode = name:
    { amount ? null, ... }@args:
    let pass = removeAttrs args [ "amount" ];
    in (if amount != null then
      forEach (range 1 amount)
      (n: nameValuePair "${name}-${toString n}" (mkNode name pass))
    else
      (nameValuePair name (mkNode name pass)));
in mkNodes
