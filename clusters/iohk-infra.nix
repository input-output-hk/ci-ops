{ targetEnv, smaller, small, small-cpr, medium, medium-cpr, medium-ng-cpr, medium-ng, medium-cpr-reserved, large-storage }:
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

  mkBenchmarkBuildkite = hostIdSuffix: {
    imports = [
      smaller
      ../roles/buildkite-benchmark-agent-container.nix
    ];
    deployment.packet = {
      inherit ipxeScriptUrl;
      facility = "sjc1";
    };
    node.isBuildkite = true;
    node.isHydraSlave = false;
    services.buildkite-containers.hostIdSuffix = hostIdSuffix;
  };

  mkBenchmarkHydra = hostIdSuffix: {
    imports = [
      ../roles/hydra-slave.nix
      medium-ng-cpr
    ];
    deployment.packet = {
      inherit nixosVersion;
      facility = "ams1";
      #plan = lib.mkForce "c3.medium.x86";
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

    packet-ipxe-1 = mkHydraSlaveBuildkite "1";
    packet-ipxe-2 = mkHydraSlaveBuildkite "2";
    packet-ipxe-3 = mkHydraSlaveBuildkite "3";
    packet-ipxe-4 = mkBenchmarkBuildkite "4";

    # Tmp extra builders
    packet-ipxe-5 = mkHydraSlaveBuildkite "5";

    # Tmp locally for testing -- do not commit
    #packet-ipxe-6 = mkHydraSlaveBuildkite "6" // { deployment.packet = { inherit ipxeScriptUrl facility; }; };

    # benchmarking hydra slave
     packet-benchmark-hydra-1 = mkBenchmarkHydra "6";
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
