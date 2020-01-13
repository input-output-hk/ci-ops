{ targetEnv, small, medium }:
let
  mkNodes = import ../nix/mk-nodes.nix { inherit targetEnv; };
  pkgs = import ../nix { };
  lib = pkgs.lib;

  globals = import ../globals.nix;
  nodes = mkNodes {
    monitoring = {
      imports = [ small ../roles/monitor.nix ];
      deployment.packet.facility = "ams1";
      node.isMonitoring = true;
    };

    packet-hydra-buildkite-1 = {
      imports = [ small ../roles/buildkite-agent-containers.nix ];
      deployment.packet.facility = "ams1";
      node.isBuildkite = true;
      services.buildkite-containers.hostIdSuffix = "1";
    };
  };
in {
  # TODO This should get appended to the name in packet AFAIK
  network.description = globals.deployment;
  network.enableRollback = true;
} // nodes
