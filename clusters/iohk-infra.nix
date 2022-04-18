{ targetEnv, smaller, small, small-cpr, medium, medium-cpr, medium-ng-cpr, medium-ng, medium-cpr-reserved, large-storage, small-ng-cpr }:
let
  mkNodes = import ../nix/mk-nodes.nix { inherit targetEnv; };
  mkMacs = import ../nix/mk-macs.nix;
  pkgs = import ../nix { };
  lib = pkgs.lib;
  globals = import ../globals.nix;

  ipxeScriptUrl = "https://netboot.gsc.io/installer-pre/x86/netboot.ipxe";
  nixosVersion = "nixos_21_05.01";
  # ipxeScriptUrl = "http://images.platformequinix.net/nixos/installer-pre/x86/netboot.ipxe";

  facility = "ams1";
  reservationId = "next-available";

  mkHydraSlaveBuildkite = hostIdSuffix: {
    imports = [
      medium-cpr
      ../roles/hydra-slave.nix
      ../roles/buildkite-agent-containers.nix
      # Remove hercules due to OOM
      #../roles/hercules-agent.nix
    ];
    deployment.packet = { inherit ipxeScriptUrl facility reservationId; };
    node.isBuildkite = true;
    node.isHydraSlave = true;
    services.buildkite-containers.hostIdSuffix = hostIdSuffix;
  };

  mkBenchmarkBuildkite = hostIdSuffix: instance: facility: queue: {
    imports = [
      instance
      ../roles/buildkite-benchmark-agent-container.nix
    ];
    deployment.packet = {
      inherit nixosVersion facility;
    };
    node.isBuildkite = true;
    node.isHydraSlave = false;
    services.buildkite-containers.hostIdSuffix = hostIdSuffix;
    services.buildkite-containers.queue = queue;
  };

  mkBenchmarkHydra = hostIdSuffix: {
    imports = [
      ../roles/hydra-slave.nix
      small-ng-cpr
    ];
    deployment.packet = {
      nixosVersion = "nixos_21_11";
      facility = "ams1";
    };
    # boot.loader.grub = {
    #   efiSupport = false;
    #   enable = true;
    #   version = 2;
    #   device = "/dev/sda";
    # };
    node.isBuildkite = false;
    node.isHydraSlave = true;
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

    packet-ipxe-sonarqube-1 = {
      imports = [
        medium-cpr
      ];
      deployment.packet = { inherit ipxeScriptUrl facility; };
    };

    packet-ipxe-plutus-1 = {
      imports = [
        small
        ../roles/plutus.nix
        ({ resources, lib, ... }:
          {
            deployment.packet.keyPair = lib.mkForce resources.packetKeyPairs.plutus;
          }
        )
      ];
      deployment.packet = {
        inherit ipxeScriptUrl facility;
        project = lib.mkForce (import ../secrets/packet-plutus-ci.nix).project;
        accessKeyId = lib.mkForce (import ../secrets/packet-plutus-ci.nix).accessKeyId;
      };
    };

    # TODO: rename ipxe-# to ci-builder-#
    packet-ipxe-1 = mkHydraSlaveBuildkite "1";
    packet-ipxe-2 = mkHydraSlaveBuildkite "2";
    packet-ipxe-3 = mkHydraSlaveBuildkite "3";
    packet-ipxe-5 = mkHydraSlaveBuildkite "5";

    # TODO: rename ipxe-4 to p-bk-b-1
    packet-ipxe-4 = mkBenchmarkBuildkite "4" small "sjc1" "benchmark";
    # packet-buildkite-bench-2
    p-bk-b-2 = mkBenchmarkBuildkite "9" small "sjc1" "benchmark";
    packet-buildkite-bench-2 = mkBenchmarkBuildkite "8" medium-ng-cpr "da11" "benchmark_large";

    # benchmarking hydra slave
     packet-benchmark-hydra-1 = mkBenchmarkHydra "6";
     packet-benchmark-hydra-2 = mkBenchmarkHydra "7";
     packet-benchmark-hydra-3 = mkBenchmarkHydra "8";
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
