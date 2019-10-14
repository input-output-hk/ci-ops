{ globals, ... }:

let
  inherit (globals) regions accessKeyId;

  mkRule = region: {
    name = "allow-monitoring-collection-${region}";
    value = { nodes, resources, lib, ... }:
    let
      monitoringSourceIp = resources.elasticIPs.monitor-ip;
    in {
      inherit region accessKeyId;
      _file = ./allow-monitoring-collection.nix;
      description = "Monitoring collection";
      rules = lib.optionals (nodes ? "monitor")
        [{
          protocol = "tcp";
          fromPort = 8000; toPort = 8000; # jormungandr prometheus exporter
          sourceIp = monitoringSourceIp;
        }{
          protocol = "tcp";
          fromPort = 9100; toPort = 9100; # prometheus exporters
          sourceIp = monitoringSourceIp;
        }{
          protocol = "tcp";
          fromPort = 9102; toPort = 9102; # statd exporter
          sourceIp = monitoringSourceIp;
        }{
          protocol = "tcp";
          fromPort = 9113; toPort = 9113; # nginx exporter
          sourceIp = monitoringSourceIp;
        }{
          protocol = "tcp";
          fromPort = 12760; toPort = 12761; # iohk-monitoring-framework
          sourceIp = monitoringSourceIp;
        }];
    };
  };
in {
  resources.ec2SecurityGroups = builtins.listToAttrs (map mkRule regions);
}
