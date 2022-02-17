{ config, ... }: let
  cfg = config.services.buildkite-containers;
in {
  imports = [ ../modules/buildkite-agent-containers.nix ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 90;
    nixAutoMinFreeGB   = 60;
    nixHourlyMaxFreedGB = 120;
    nixHourlyMinFreeGB = 90;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.buildkite-containers.containerList = [
    { containerName = "ci${cfg.hostIdSuffix}-bench"; guestIp = "10.254.1.11"; prio = "9"; tags = { system = "x86_64-linux"; queue = cfg.queue; }; }
  ];
}
