{ globals ? import ../globals.nix, ... }:
let
  inherit (globals.packet) credentials;

  cluster = import ../clusters/iohk-infra.nix {
    targetEnv = "packet";
    smaller = ../physical/packet/t3.small.nix;
    small = ../physical/packet/c1.small.nix;
    small-cpr = ../physical/packet/c1-cpr.small.nix;
    small-ng-cpr = ../physical/packet/c3-cpr.small.nix;
    medium = ../physical/packet/c2.medium.nix;
    medium-cpr = ../physical/packet/c2-cpr.medium.nix;
    medium-ng = ../physical/packet/c3.medium.nix;
    medium-ng-cpr = ../physical/packet/c3-cpr.medium.nix;
    medium-cpr-reserved = ../physical/packet/c2-cpr-reserved.medium.nix;
    large-storage = ../physical/packet/s3-cpr.large.nix;
  };

  lib = (import ../nix { }).lib;

  settings = {
    resources.packetKeyPairs.global = credentials;
    resources.packetKeyPairs.plutus = import ../secrets/packet-plutus-ci.nix;

    resources.route53RecordSets = __listToAttrs (map (name: {
      name = "${name}-route53";
      value = { resources, ... }: {
        domainName = "${name}.${globals.domain}.";
        zoneName = "${globals.domain}.";
        recordValues = [ resources.machines.${name} ];
      };
    }) (__filter (n: n != "network" && n != "resources" && n != "mac-mini-1" && n != "mac-mini-2") (__attrNames cluster)));
    require = [
      ../clusters/equinix
      ../clusters/new-cluster.nix
    ];
    # applies to EVERY machine in the cluster
    defaults = {
      imports = [
        ../modules/ssh-keys.nix
      ];
      services.openssh.passwordAuthentication = false;
    };
  };
in cluster // settings
