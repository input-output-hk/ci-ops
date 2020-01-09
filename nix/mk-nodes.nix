{ targetEnv }:
let
  inherit (import ../nix { }) lib;
  inherit (lib)
    range listToAttrs mapAttrsToList nameValuePair foldl forEach filterAttrs
    recursiveUpdate;

  # defs: passed from clusters/$NIXOPS-DEPLOYMENT.nix as the node defs
  mkNodes = defs:
    listToAttrs (foldl foldNodes {
      nodes = [ ];
    } (mapAttrsToList definitionToNode defs)).nodes;

  # Add additonal logic here in the future if needed
  foldNodes = { nodes }: elem: {
      nodes = nodes ++ [ elem ];
    };

  mkNode = args:
    recursiveUpdate {
      imports = args.imports ++ [ ../modules/common.nix ];
      deployment.targetEnv = targetEnv;
      _module.args.globals = import ../globals.nix;
    } args;

  definitionToNode = name:
    { amount ? null, ... }@args:
    let pass = removeAttrs args [ "amount" ];
    in (if amount != null then
      forEach (range 1 amount)
      (n: nameValuePair "${name}-${toString n}" (mkNode pass))
    else
      (nameValuePair name (mkNode pass)));
in mkNodes
