{ config, ... }:
{
  imports = [
    ../modules/hydra-master-common.nix
    ../modules/hydra-master-main.nix
    ../modules/auto-gc.nix
    ../modules/nix_nsswitch.nix
    ../modules/hydra-master-wireguard.nix
    ../modules/hydra-monitor.nix
  ];

  services = {
    auto-gc = {
      nixAutoMaxFreedGB  = 260;
      nixAutoMinFreeGB   = 160;
      nixHourlyMaxFreedGB = 260;
      nixHourlyMinFreeGB = 150;
      nixWeeklyGcFull = false;
    };
    hydra-monitor = {
      enable = true;
      bindingAddress = "${config.node.wireguardIP}";
      bindingPort = 8000;
      scrapeTarget = "https://hydra.ci.iohkdev.io/queue-runner-status";
      openFirewallPort = true;
    };
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
