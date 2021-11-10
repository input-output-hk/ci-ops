{ config, pkgs, lib, ... }:

with lib;

let cfg = config.services.monitoring-exporters;
in {

  options = {
    services.monitoring-exporters = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable monitoring exporters.  Metrics exporters are
          prometheus and nginx by default.  Log exporting is
          available via journalbeat by default.
          Metrics export can be selectively disabled with the metrics option.
          Log export be selectively disabled with the logging option.
        '';
      };

      metrics = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable metrics exporters via prometheus and nginx.
          See also the corresponding metrics server option in
          the monitoring-services.nix module:
          config.services.monitoring-services.metrics
        '';
      };

      logging = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable logging exporter via journalbeat to graylog.
          See also the corresponding logging server option in
          the monitoring-services.nix module:
          config.services.monitoring-services.logging
        '';
      };

      graylogHost = mkOption {
        type = types.str;
        example = "graylog:5044";
        description = ''
          The host port under which Graylog is externally reachable.
        '';
      };

      papertrail.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable papertrail.
        '';
      };

      useWireguardListeners = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Bind the wg ip instead of globally where possible.
        '';
      };

      ownIp = mkOption {
        type = types.str;
        description = ''
          The address a remote prometheus node will use to contact this machine.
          Typically set to the wireguard ip if available.
        '';
      };
    };
  };

  config = let
    bindingIp = if cfg.useWireguardListeners then "${cfg.ownIp}" else "0.0.0.0";
  in mkIf cfg.enable (mkMerge [
    { nixpkgs.overlays = [ (import ../overlays/monitoring-exporters.nix) ]; }

    (mkIf (config.services.nginx.enable && cfg.metrics) {
      services.nginx = {
        appendHttpConfig = ''
          vhost_traffic_status_zone;
          server {
            listen ${bindingIp}:9113;
            location /status {
              vhost_traffic_status_display;
              vhost_traffic_status_display_format html;
            }
          }
        '';
      };
      networking.firewall.allowedTCPPorts = [ 9113 ];
    })

    (mkIf cfg.metrics {
      services = {
        systemd-exporter = {
          enable = true;
          host = bindingIp;
          unitWhitelist = [ ".*\\.service$"];
          after = [ "wg-quick-wg0.service" ];
        };
        prometheus.exporters.node = {
          enable = true;
          listenAddress = bindingIp;
          enabledCollectors = [
            "systemd"
            "tcpstat"
            "conntrack"
            "diskstats"
            "entropy"
            "filefd"
            "filesystem"
            "loadavg"
            "meminfo"
            "netdev"
            "netstat"
            "stat"
            "time"
            "ntp"
            "timex"
            "vmstat"
            "logind"
            "interrupts"
            "ksmd"
            "processes"
          ];
        };
      };
      systemd.services.prometheus-node-exporter.after = [ "wg-quick-wg0.service" ];
      # Node exporter default port
      networking.firewall.allowedTCPPorts = [
        9100
        config.services.systemd-exporter.port
      ];
    })

    (mkIf cfg.logging {
      services.journalbeat = {
        enable = true;
        package = pkgs.journalbeat7;
        extraConfig = ''
          journalbeat:
            seek_position: cursor
            cursor_seek_fallback: tail
            write_cursor_state: true
            cursor_flush_period: 5s
            clean_field_names: true
            convert_to_numbers: false
            move_metadata_to_field: journal
            default_type: journal
          output.logstash:
            hosts: ["${cfg.graylogHost}"]
          journalbeat.inputs:
            - paths:
              - "/var/log/journal/"
        '';
      };
    })

    (mkIf cfg.papertrail.enable {
      systemd.services.papertrail = {
        description = "Papertrail.com log aggregation";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          ${pkgs.systemd}/bin/journalctl -f | ${pkgs.nmap}/bin/ncat --ssl logs5.papertrailapp.com 43689
        '';
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStartSec = 0;
          KillSignal = "SIGINT";
        };
      };
    })
  ]);
}
