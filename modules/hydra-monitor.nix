{ pkgs, lib, config, ... }:

let
  cfg = config.services.hydra-monitor;

  inherit (lib)
    mkIf mkOption types mkEnableOption concatStringsSep optionals optionalAttrs;
in {
  options = {
    services.hydra-monitor = {
      enable = mkEnableOption "hydra monitor";

      scrapeTarget = mkOption {
        type = types.str;
        default = "https://hydra.ci.iohkdev.io/queue-runner-status";
        description = "The default scrape target for hydra metrics";
      };

      bindingAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "The default binding address to serve the hydra re-exported metrics at";
      };

      bindingPort = mkOption {
        type = types.port;
        default = 8000;
        description = "The default port to serve the hydra re-exported metrics at";
      };

      openFirewallPort = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the bindingPort up on the firewall";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewallPort [ cfg.bindingPort ];

    systemd.services.hydra-monitor = {
      wantedBy = [ "multi-user.target" ];
      after = [ "hydra-queue-runner.service" ];

      serviceConfig = {
        User = "hydra-monitor";
        Group = "hydra-monitor";
        DynamicUser = true;
        StartLimitBurst = 50;
        ExecStart = pkgs.callPackage ./hydra-monitor { inherit (cfg) scrapeTarget bindingAddress bindingPort; };
        Restart = "always";
        RestartSec = "15s";
      };
    };
  };
}
