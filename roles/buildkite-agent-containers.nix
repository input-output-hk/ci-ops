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
    { containerName = "ci${cfg.hostIdSuffix}-1"; guestIp = "10.254.1.11"; prio = "9"; metadata = "system=x86_64-linux"; }
    { containerName = "ci${cfg.hostIdSuffix}-2"; guestIp = "10.254.1.12"; prio = "8"; metadata = "system=x86_64-linux"; }
    { containerName = "ci${cfg.hostIdSuffix}-3"; guestIp = "10.254.1.13"; prio = "7"; metadata = "system=x86_64-linux"; }
    { containerName = "ci${cfg.hostIdSuffix}-4"; guestIp = "10.254.1.14"; prio = "6"; metadata = "system=x86_64-linux"; }
    { containerName = "ci${cfg.hostIdSuffix}-5"; guestIp = "10.254.1.15"; prio = "5"; metadata = "system=x86_64-linux"; }
  ];
}
