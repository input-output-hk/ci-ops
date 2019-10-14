{ pkgs, lib, config, nodes, resources, ... }:
let
  inherit (import ../globals.nix) domain;
  inherit (lib) mapAttrs hasPrefix listToAttrs attrValues;

  monitoringFor = name:
    if (hasPrefix "stake-" name) || (hasPrefix "relay-" name) then {
      hasJormungandrPrometheus = true;
    } else if (name == "faucet") || (name == "explorer") then {
      hasJormungandrPrometheus = true;
      hasNginx = true;
    } else if name == "monitor" then {
      hasNginx = true;
    } else
      { };

  monitoredNodes = {
    ec2 = listToAttrs (attrValues (mapAttrs (name: node: {
      name = "${name}-ip";
      value = monitoringFor name;
    }) nodes));

    libvirtd = listToAttrs (attrValues (mapAttrs (name: node: {
      inherit name;
      value = monitoringFor name;
    }) nodes));
  };

in {
  imports = [ ../modules/monitoring-services.nix ../modules/common.nix ];

  deployment.ec2.securityGroups = [
    resources.ec2SecurityGroups."allow-public-www-https-${config.node.region}"
  ];

  services.monitoring-services = {
    enable = true;
    webhost = config.node.fqdn;
    enableACME = config.deployment.targetEnv == "ec2";

    grafanaCreds = import ../secrets/grafana-creds.nix;
    graylogCreds = import ../secrets/graylog-creds.nix;
    oauth = import ../secrets/oauth.nix;

    monitoredNodes = monitoredNodes.${config.deployment.targetEnv};
  };

  systemd.services.graylog.environment.JAVA_OPTS = ''
    -Djava.library.path=${pkgs.graylog}/lib/sigar -Xms1g -Xmx1g -XX:NewRatio=1 -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow
  '';

  services.elasticsearch.extraJavaOptions = [ "-Xms1g" "-Xmx1g" ];
}
