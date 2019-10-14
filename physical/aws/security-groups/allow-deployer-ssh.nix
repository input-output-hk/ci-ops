{ globals, ... }:

let
  inherit (globals) regions accessKeyId;

  mkRule = region: {
    name = "allow-deployer-ssh-${region}";
    value = {
      inherit region accessKeyId;
      _file = ./allow-deployer-ssh.nix;
      description = "SSH";
      rules = [
        {
          protocol = "tcp"; # TCP
          fromPort = 22;
          toPort = 22;
          sourceIp = "0.0.0.0/0"; # TODO: fixme
        }
      ];
    };
  };
in {
  resources.ec2SecurityGroups = __listToAttrs (map mkRule regions);
}
