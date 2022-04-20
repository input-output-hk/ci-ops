{ pkgs, lib, config, resources, name, ... }: let
  cfg = config.services.buildkite-containers;
  ssh-keys = config.services.ssh-keys;
in {
  imports = [ ../modules/buildkite-agent-containers.nix ];

  deployment.keys = {
    "buildkite-github-token" = {
      keyFile = ../secrets/buildkite_github_token;
      user = "buildkite-agent-iohk";
    };
  };

  users.extraUsers.root.openssh.authorizedKeys.keys = ssh-keys.devOps ++ ssh-keys.plutus-developers;

  services.auto-gc = {
    nixAutoMaxFreedGB  = 100;
    nixAutoMinFreeGB   = 60;
    nixHourlyMaxFreedGB = 200;
    nixHourlyMinFreeGB = 100;
    nixWeeklyGcFull = true;
    nixWeeklyGcOnCalendar = "Sat *-*-* 20:00:00";
  };

  services.buildkite-containers.containerList = [
    {
      containerName = "ci${cfg.hostIdSuffix}-1";
      guestIp = "10.254.1.11";
      tags = {
        system = "x86_64-linux";
        queue = "plutus";
      };
    }
  ];
}
