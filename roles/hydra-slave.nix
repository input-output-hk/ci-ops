{ config, ... }: let
  cfg = config.services.hydra-slave;
in {
  imports = [ ../modules/hydra-slave.nix ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 900;
    nixAutoMinFreeGB   = 120;
    nixHourlyMaxFreedGB = 900;
    nixHourlyMinFreeGB = 100;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 00:00:00";
  };

  services.hydra-slave.cores = 10;
}
