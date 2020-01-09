{ globals ? import ../globals.nix, ... }:
let
  inherit (globals.packet) credentials;

  cluster = import ../clusters/iohk-infra.nix {
    targetEnv = "packet";
    small = ../physical/packet/c1.small.nix;
    medium = ../physical/packet/c2.medium.nix;
  };

  lib = (import ../nix { }).lib;

  settings = {
    resources.packetKeyPairs.global = credentials;
    resources.route53RecordSets = lib.mapAttrs' (name: value: {
      name = "${name}-route53";
      value = { resources, ... }: {
        domainName = "${name}.${globals.domain}.";
        zoneName = "${globals.domain}.";
        recordValues = [ resources.machines.${name} ];
      };
    }) { # todo, need to use resources.machines
      monitoring = 1;
    };
  };
in cluster // settings
