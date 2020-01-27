{ config, ... }:
{
  imports = [
    ../modules/hydra-master-common.nix
    ../modules/hydra-master-main.nix
    ../modules/auto-gc.nix
    ../modules/nix_nsswitch.nix
    ../modules/hydra-master-wireguard.nix
  ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 150;
    nixAutoMinFreeGB   = 120;
    nixHourlyMaxFreedGB = 150;
    nixHourlyMinFreeGB = 100;
    nixWeeklyGcFull = false;
  };

  # An additional ZFS vol outside of the usual physical spec was created manually for ease of Hydra db snapshotting and backups with:
  #   mkdir /var/db
  #   zfs create zpool/db -o mountpoint=legacy
  #   mount zpool/db -t zfs /var/db
  #
  # This remounts the new ZFS vol each boot:
  fileSystems."/var/db" = {
    fsType = "zfs";
    device = "zpool/db";
  };
}
