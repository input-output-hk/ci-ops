{ globals, ... }:

let
  inherit (globals) regions accessKeyId;

  mkRule = region: {
    name = "allow-all-${region}";
    value = {
      inherit region accessKeyId;
      _file = ./allow-all.nix;
      description = "Allow all ${region}";
      rules = [{
        protocol = "-1"; # all
        fromPort = 0; toPort = 65535;
        sourceIp = "0.0.0.0/0";
      }];
    };
  };
in {
  resources.ec2SecurityGroups = __listToAttrs (map mkRule regions);
}
