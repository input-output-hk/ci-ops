# _module.args doesn't support passing to containers, so we can use a module for keys instead
{ pkgs, config, lib, ... }:
let
  cfg = config.services.ssh-keys;
  sources = import ../nix/sources.nix;
  original-ssh-keys = import (sources.ops-lib + "/overlays/ssh-keys.nix") lib;
  allKeysFrom = keys: __concatLists (__attrValues keys);
  inherit (original-ssh-keys) devOps csl-developers plutus-developers remoteBuilderKeys;
  inherit (builtins) typeOf;
  inherit (lib) types mkOption;
in with types; {
  options = {
    services.ssh-keys = {
      devOps = mkOption {
        type = listOf str;
        default = allKeysFrom devOps;
        description = "Default devOps ssh authorized keys";
      };

      ciInfra = mkOption {
        type = listOf str;
        default = allKeysFrom devOps ++ allKeysFrom { inherit (csl-developers) angerman; };
        description = "Default ciInfra ssh authorized keys";
      };

      buildSlaveKeys = mkOption {
        type = attrsOf (listOf str);
        default = {
          macos = allKeysFrom devOps ++ allKeysFrom remoteBuilderKeys;
          linux = remoteBuilderKeys.hydraBuildFarm;
        };
        description = "Default buildSlave ssh authorized keys";
      };

      plutus-developers = mkOption {
        type = listOf str;
        default = allKeysFrom plutus-developers;
        description = "Default plutus-developers ssh authorized keys";
      };
    };
  };
}
