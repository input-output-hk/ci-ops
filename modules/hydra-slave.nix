{ config, lib, pkgs, name, ... }:
let
  cfg = config.services.hydra-slave;
  ssh-keys = config.services.ssh-keys;
in with lib;
{
  imports = [ ./auto-gc.nix
              ./nix_nsswitch.nix
            ];

  options = {
    services.hydra-slave = {
      cores = mkOption {
        type = mkOptionType {
          name = "hydra-slave-cores";
          check = t: isInt t && t >= 0;
        };
        default = 0;
        description = ''
          The number of slave cores to utilize per build job.
          0 is defined as unlimited.  0 is the default.
        '';
      };
    };
  };

  config = {
    nix = {
      buildCores = mkForce cfg.cores;
      trustedBinaryCaches = mkForce [];
      binaryCaches = mkForce [ "https://cache.nixos.org" "https://cache.iog.io" ];
      binaryCachePublicKeys = mkForce [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
      ];
      extraOptions = ''
        # Max of 2 hours to build any given derivation on Linux.
        # See ../nix-darwin/modules/basics.nix for macOS.
        timeout = ${toString (3600 * 2)}
      '';
    };

    users.extraUsers.root.openssh.authorizedKeys.keys =
      ssh-keys.ciInfra ++
      map (key: ''
        command="nice -n20 nix-store --serve --write" ${key}
      '') ssh-keys.buildSlaveKeys.linux;
  };
}
