{ globals, ... }:

let
  inherit (globals) regions accessKeyId;

  mkRule = region: {
    name = "allow-jormungandr-${region}";
    value = {
      inherit region accessKeyId;
      _file = ./allow-jormungandr.nix;
      description = "Allow jormungandr ${region}";
      rules = [{
        protocol = "tcp"; # all
        fromPort = 3000; toPort = 3000;
        sourceIp = "0.0.0.0/0";
      }];
    };
  };
in {
  resources.ec2SecurityGroups = __listToAttrs (map mkRule regions);
}
