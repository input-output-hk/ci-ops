let
  inherit (builtins) getEnv removeAttrs toString toJSON attrNames;
  inherit ((import ../nix { }).lib) filterAttrs;

  globals = import ./globals.nix;
  nixopsDeployment = getEnv "NIXOPS_DEPLOYMENT";
  deployment = import (../deployments + "/${nixopsDeployment}.nix") { };

in rec {
  inherit (deployment) resources;

  machines = removeAttrs deployment [ "resources" "monitoring" "network" ];
  all = removeAttrs deployment [ "resources" "network" ];

  initalResourcesNames = __concatLists (map __attrNames
    (__attrValues (builtins.removeAttrs resources [ "elasticIPs" ])));

  stakes = filterAttrs (name: node: node.node.isStake or false) machines;
  relays = filterAttrs (name: node: let n = node.node; in
    n.isTrustedPeer or
    n.isTrustedPoolPeer or
    n.isRelay or
    n.isExplorer or
    n.isExplorerApi or
    n.isFaucet or false)
    machines;

  allNames = __attrNames all;
  allStrings = toString allNames;

  stakesNames = __attrNames stakes;
  stakeStrings = toString stakesNames;

  #relaysNames = __filter (r: r != "relay-a-backup-1") (__attrNames relays);
  relaysNames = __attrNames relays;
  relayStrings = toString relaysNames;

  string = toString (attrNames machines);
  json = toJSON (attrNames machines);
}
