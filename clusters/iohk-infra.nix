{ targetEnv, small, small-cpr, medium, medium-cpr, medium-cpr-reserved }:
let
  mkNodes = import ../nix/mk-nodes.nix { inherit targetEnv; };
  mkMacs = import ../nix/mk-macs.nix;
  pkgs = import ../nix { };
  lib = pkgs.lib;
  globals = import ../globals.nix;

  ipxeScriptUrl = "http://907e8786.packethost.net/result/x86/netboot.ipxe";
  facility = "ams1";
  reservationId = "next-available";

  mkHydraSlaveBuildkite = hostIdSuffix: {
    imports = [
      medium-cpr
      ../roles/hydra-slave.nix
      ../roles/buildkite-agent-containers.nix
      ../roles/hercules-agent.nix
    ];
    deployment.packet = { inherit ipxeScriptUrl facility reservationId; };
    node.isBuildkite = true;
    node.isHydraSlave = true;
    services.buildkite-containers.hostIdSuffix = hostIdSuffix;
  };

  nodes = mkNodes {
    monitoring = {
      imports = [ small ../roles/monitor.nix ];
      deployment.packet = { inherit ipxeScriptUrl facility; };
      node.isMonitoring = true;
    };

    packet-ipxe-hydra-1 = {
      imports = [
        medium-cpr
        ../roles/hydra.nix
        ../roles/bors.nix
      ];
      deployment.packet = { inherit ipxeScriptUrl facility reservationId; };
      node.isHydra = true;
      node.isBors = true;
    };

    packet-ipxe-1 = mkHydraSlaveBuildkite "1";
    packet-ipxe-2 = mkHydraSlaveBuildkite "2";
    packet-ipxe-3 = mkHydraSlaveBuildkite "3";
  };

  macs = mkMacs {
    mac-mini-1 = {
      imports = [ ../roles/mac.nix ];
      hostid = "742a9d59";
      node.isMac = true;
    };
    mac-mini-2 = {
      imports = [ ../roles/mac.nix ];
      hostid = "34d9f89a";
      node.isMac = true;
    };
  };
in {
  network.description = globals.deployment;
  network.enableRollback = true;
} // nodes // macs
