{ pkgs, lib, config, resources, name, ... }: let
  cfg = config.services.buildkite-containers;
  ssh-keys = config.services.ssh-keys;
in {
  imports = [ ../modules/buildkite-agent-containers.nix ];

  users.extraUsers.root.openssh.authorizedKeys.keys = ssh-keys.devOps ++ ssh-keys.plutus-developers;
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';

  services.auto-gc = {
    nixAutoMaxFreedGB  = 200;
    nixAutoMinFreeGB   = 60;
    nixHourlyMaxFreedGB = 200;
    nixHourlyMinFreeGB = 40;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.buildkite-containers.containerList = [
    { containerName = "ci${cfg.hostIdSuffix}-1"; guestIp = "10.254.1.11"; metadata = "system=x86_64-linux,queue=plutus"; }
  ];
}
