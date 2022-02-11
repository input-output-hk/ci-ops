{ config, ... }: let
  cfg = config.services.hydra-slave;
in {
  imports = [ ../modules/hydra-slave.nix ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 150;
    nixAutoMinFreeGB   = 90;
    nixHourlyMaxFreedGB = 600;
    nixHourlyMinFreeGB = 150;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.hydra-slave.cores = 10;
}
