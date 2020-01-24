{ config, ... }:
{
  imports = [
    ../modules/hydra-master-common.nix
    ../modules/hydra-master-main.nix
     ../modules/auto-gc.nix
     ../modules/nix_nsswitch.nix

    # This module will require some additional work for the macs -- will work on last
    # ../modules/hydra-master-wireguard.nix
  ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 150;
    nixAutoMinFreeGB   = 120;
    nixHourlyMaxFreedGB = 150;
    nixHourlyMinFreeGB = 100;
    nixWeeklyGcFull = false;
  };

  fileSystems."/var/db" = {
    fsType = "zfs";
    device = "zpool/db";
  };
}
