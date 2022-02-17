{ config, lib, ... }: let
  cfg = config.services.buildkite-containers;
in {
  imports = [ ../modules/buildkite-agent-containers.nix ];

  services.auto-gc = {
    nixAutoMaxFreedGB  = 150;
    nixAutoMinFreeGB   = 90;
    nixHourlyMaxFreedGB = 600;
    nixHourlyMinFreeGB = 150;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.buildkite-containers.containerList = let
    mkContainer = n: prio: { containerName = "ci${cfg.hostIdSuffix}-${toString n}"; guestIp = "10.254.1.1${toString n}"; inherit prio; tags = { system = "x86_64-linux"; queue = cfg.queue; }; };
  in map (n: mkContainer n (toString (10-n))) (lib.range 1 5);
}
