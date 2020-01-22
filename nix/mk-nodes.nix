{ targetEnv }:
let
  inherit (import ../nix { }) lib;
  inherit (lib)
    range listToAttrs mapAttrsToList nameValuePair foldl forEach filterAttrs
    recursiveUpdate;

  sources = import ./sources.nix;
  original-ssh-keys = import (sources.ops-lib + "/overlays/ssh-keys.nix") lib;
  allKeysFrom = keys: __concatLists (__attrValues keys);
  inherit (original-ssh-keys) devOps csl-developers remoteBuilderKeys;

  ssh-keys = {
    devOps = allKeysFrom devOps;
    ciInfra = ssh-keys.devOps ++ allKeysFrom { inherit (csl-developers) angerman; };
    buildSlaveKeys = {
      macos = ssh-keys.devOps ++ allKeysFrom remoteBuilderKeys;
      linux = remoteBuilderKeys.hydraBuildFarm;
    };
  };

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
      _module.args = { inherit globals ssh-keys; };
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
