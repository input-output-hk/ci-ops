{ pkgs, lib, config, nodes, resources, name, deploymentName, globals, ... }:
let
  sources = import ../nix/sources.nix;

  inherit (lib) mapAttrs' hasPrefix listToAttrs attrValues nameValuePair;

  monitoringFor = nodeName: node:
    let cfg = node.config.node;
    in {
      hasHydraPrometheus = cfg.isHydra;
      hasNginx = cfg.isMonitoring;
      labels = { alias = nodeName; };
    };

  loadFile = file:
    if __pathExists file then import file else {};

in {
  imports = [
    ../modules/monitoring-services.nix
    ../modules/monitoring-alerts.nix
  ];

  node.fqdn = "${name}.${globals.domain}";

  deployment.ec2.securityGroups = [
    resources.ec2SecurityGroups."allow-public-www-https-${config.node.region}"
    resources.ec2SecurityGroups."allow-wireguard-${config.node.region}"
  ];

  services.monitoring-services = {
    enable = true;
    enableWireguard = true;
    useWireguardListeners = true;
    ownIp = config.node.wireguardIP;

    webhost = config.node.fqdn;
    enableACME = config.deployment.targetEnv != "libvirtd";
    extraHeader = "Deployment Name: ${deploymentName}<br>";

    deadMansSnitch = loadFile ../secrets/dead-mans-snitch.nix;
    grafanaCreds = loadFile ../secrets/grafana-creds.nix;
    graylogCreds = loadFile ../secrets/graylog-creds.nix;
    oauth = loadFile ../secrets/oauth.nix;
    pagerDuty = loadFile ../secrets/pager-duty.nix;

    monitoredNodes = mapAttrs'
      (nodeName: node: nameValuePair nodeName (monitoringFor nodeName node)) nodes;

    applicationDashboards = [ ];
  };

  systemd.services.graylog.environment.JAVA_OPTS = ''
    -Djava.library.path=${pkgs.graylog}/lib/sigar -Xms3g -Xmx3g -XX:NewRatio=1 -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow
  '';

  services.elasticsearch.extraJavaOptions = [ "-Xms6g" "-Xmx6g" ];
}
