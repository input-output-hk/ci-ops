{ lib, config, name, nodes, resources, ...}:
let
  uniqueKey = "wg_${name}";
  sharedKey = "wg_shared";
  listenPort = 17777;
  inherit (lib) mkOption types;

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
    networking.extraHosts = ''
      ${nodes.monitoring.config.node.wireguardIP} monitoring-wg
    '';

    deployment.keys.${uniqueKey}.keyFile = ../. + "/secrets/wireguard/${name}.private";
    deployment.keys.${sharedKey}.keyFile = ../. + "/secrets/wireguard/shared.private";

    systemd.services."wg-quick-wg0" = {
      after = [ "${uniqueKey}.sk-key.service" "${sharedKey}.sk-key.service" ];
      wants = [ "${uniqueKey}.sk-key.service" "${sharedKey}.sk-key.service" ];
    };

    boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

    deployment.ec2.securityGroups = [
      resources.ec2SecurityGroups."allow-wireguard-${config.node.region}"
    ];

    networking.wg-quick.interfaces.wg0 = {
      inherit listenPort;
      address = [ "${config.node.wireguardIP}/24" ];
      privateKeyFile = "/run/keys/${uniqueKey}";

      peers = [
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
