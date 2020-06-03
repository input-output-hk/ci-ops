{ config, ... }:
{
  imports = [
    ../modules/hydra-master-common.nix
    ../modules/hydra-master-main.nix
    ../modules/auto-gc.nix
    ../modules/nix_nsswitch.nix
    ../modules/hydra-master-wireguard.nix
    ../modules/hydra-monitor.nix
    ../modules/hydra-crystal-notify.nix
  ];

  services = {
    auto-gc = {
      nixAutoGcEnable = false;
      nixHourlyGcEnable = false;
      nixWeeklyGcFull = true;
      nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
    };
    hydra-monitor = {
      enable = true;
      bindingAddress = "${config.node.wireguardIP}";
      bindingPort = 8000;
      scrapeTarget = "https://hydra.ci.iohkdev.io/queue-runner-status";
      openFirewallPort = true;
    };
    hydra-crystal-notify = {
      enable = true;
      mockMode = false;
    };
    postgresql = {
      extraConfig = ''
        max_connections 200
      '';
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
