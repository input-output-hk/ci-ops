let
  inherit (import ../nix { }) lib;
  inherit (lib) listToAttrs foldl mapAttrsToList nameValuePair recursiveUpdate;
  globals = import ../globals.nix;

  # defs: passed from clusters/$NIXOPS-DEPLOYMENT.nix as the mac defs
  mkMacs = defs:
    listToAttrs (foldl foldMacs {
      macs = [ ];
    } (mapAttrsToList definitionToMac defs)).macs;

  # Add additonal logic here in the future if needed
  foldMacs = { macs }: elem: {
      macs = macs ++ [ elem ];
    };

  mkMac = name: spec: args: { config, ... }:
    recursiveUpdate {
      require = [ ../modules/cloud.nix ../modules/mac-host-common.nix ];
      deployment = {
        targetHost = config.node.wireguardIP;
      };
      networking = {
        hostName = name;
        hostId = spec.hostid;
        wireguard.interfaces.wg0.ips = [ "${config.node.wireguardIP}/24" ];
      };
      _module.args = { inherit globals; };
    } args;

  definitionToMac = name: { hostid, ... }@args:
    let pass = removeAttrs args [ "hostid" ];
    in nameValuePair name (mkMac name { inherit hostid; } pass);
in mkMacs
