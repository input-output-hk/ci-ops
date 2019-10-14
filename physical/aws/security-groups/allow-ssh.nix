{ globals, ... }:

let
  inherit (globals) regions accessKeyId;

  mkRule = region: {
    name = "allow-ssh-${region}";
    value = {
      inherit region accessKeyId;
      _file = ./allow-ssh.nix;
      description = "Allow SSH ${region}";
      rules = [{
        protocol = "tcp"; # all
        fromPort = 22; toPort = 22;
        sourceIp = "0.0.0.0/0";
      }];
    };
  };
in {
  resources.ec2SecurityGroups = __listToAttrs (map mkRule regions);
}
