{ config, ... }: let
  cfg = config.services.buildkite-containers;
in {
  imports = [ ../modules/buildkite-agent-containers.nix ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 900;
    nixAutoMinFreeGB   = 120;
    nixHourlyMaxFreedGB = 900;
    nixHourlyMinFreeGB = 100;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.buildkite-containers.containerList = [
    { containerName = "ci${cfg.hostIdSuffix}-bench"; guestIp = "10.254.1.11"; prio = "9"; metadata = "system=x86_64-linux,queue=benchmark"; }
  ];
}
