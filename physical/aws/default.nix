{ name, config, resources, lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (config.deployment.ec2) region;
  inherit (import ../../globals.nix) accessKeyId domain;
in {
  deployment.targetEnv = "ec2";

  imports = [ ../../modules/cloud.nix ];

  deployment.ec2 = {
    region = mkDefault "eu-central-1";

    keyPair = mkDefault resources.ec2KeyPairs."ci-${region}";

    ebsInitialRootDiskSize = mkDefault 30;

    elasticIPv4 = resources.elasticIPs."${name}-ip" or "";

    securityGroups = [
      resources.ec2SecurityGroups."allow-ssh-${region}"
      resources.ec2SecurityGroups."allow-monitoring-collection-${region}"
    ];
  };

  networking.hostName = mkDefault name;

  deployment.route53 = lib.mkIf (config.node.fqdn != null) {
    inherit (config.node) accessKeyId;
    hostName = config.node.fqdn;
  };

  node = {
    inherit accessKeyId region;
    fqdn = "${name}.${domain}";
  };
}
