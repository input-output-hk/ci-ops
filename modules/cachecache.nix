{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cachecache;
  iohkops = import ../.;
in {
  options = {
    services.cachecache.enable = mkEnableOption "enable cachecache";
  };
  config = mkIf cfg.enable {
    users.users.cachecache = {
      home = "/var/lib/cachecache";
      group = "cachecache";
      isSystemUser = true;
      createHome = true;
    };
    users.groups.cachecache = {};
    systemd.services.cachecache = {
      wantedBy = [ "multi-user.target" ];
      path = [ iohkops.cachecache ];
      script = ''
        exec cachecache
      '';
      serviceConfig = {
        User = "cachecache";
        WorkingDirectory = config.users.users.cachecache.home;
      };
    };
  };
}
