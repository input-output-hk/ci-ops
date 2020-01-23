{ lib, config, name, nodes, resources, ...}:
let
  uniqueKey = "wg_${name}";
  sharedKey = "wg_shared";
  listenPort = 17777;
  inherit (lib) mkOption types optional;

  cfg = config.services.node-wireguard;

in {
  options = {
    services.node-wireguard = {
      enable  = mkOption {
        type = types.bool;
        default = true;
        description = "Enable wireguard.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [ listenPort ];
    networking.extraHosts = lib.mkIf (nodes ? monitoring) ''
      ${nodes.monitoring.config.node.wireguardIP} monitoring-wg
    '';

    deployment.keys.${uniqueKey}.keyFile = ../. + "/secrets/wireguard/${name}.private";
    deployment.keys.${sharedKey}.keyFile = ../. + "/secrets/wireguard/shared.private";

    systemd.services."wg-quick-wg0" = {
      after = [ "${uniqueKey}.sk-key.service" "${sharedKey}.sk-key.service" ];
      wants = [ "${uniqueKey}.sk-key.service" "${sharedKey}.sk-key.service" ];
      requiredBy =    (optional config.services.monitoring-exporters.enable "prometheus-node-exporter.service")
                   ++ (optional config.services.nginx.enable "nginx.service");
    };

    boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

    networking.wg-quick.interfaces.wg0 = {
      inherit listenPort;
      address = [ "${config.node.wireguardIP}/24" ];
      privateKeyFile = "/run/keys/${uniqueKey}";
      preUp = ''
        function check-key {
          for i in {1..10}; do
            if [ -f "$1" ]; then
              echo "Wireguard key \"$1\" found."
              break
            fi
            if [ "$i" -eq 10 ]; then
              echo "Wireguard key \"$1\" NOT found. Timed out."
            fi
            sleep 1
          done
        }
        check-key "/run/keys/${sharedKey}"
        check-key "/run/keys/${uniqueKey}"
      '';
      peers = lib.mkIf (nodes ? monitoring) [
        {
          allowedIPs = [ "${nodes.monitoring.config.node.wireguardIP}/32" ];
          publicKey = lib.fileContents ../secrets/wireguard/monitoring.public;
          presharedKeyFile = "/run/keys/${sharedKey}";
          endpoint = "monitoring:${toString listenPort}";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
