{ targetEnv, small, medium }:
let
  mkNodes = import ../nix/mk-nodes.nix { inherit targetEnv; };
  pkgs = import ../nix { };
  lib = pkgs.lib;

  #mkStakes = region: amount: {
  #  inherit amount;
  #  imports = [ medium ../roles/jormungandr-stake.nix ];
  #  deployment.ec2.region = region;
  #  node.isStake = true;
  #};

  #mkRelays = region: amount: {
  #  inherit amount;
  #  imports = [ medium ../roles/jormungandr-relay.nix ];
  #  deployment.ec2.region = region;
  #  node.isRelay = true;
  #};

  nodes = mkNodes {
    monitoring = {
      imports = [ small ../roles/monitor.nix ];
      deployment.packet.facility = "ams1";
      node.isMonitoring = true;
    };

    #stake-a = mkStakes "us-west" 2;
    #stake-b = mkStakes "ap-northeast" 2;
    #stake-c = mkStakes "eu-central" 2;

    #relay-a = mkRelays "us-west" 2;
    #relay-b = mkRelays "ap-northeast" 2;
    #relay-c = mkRelays "eu-central" 2;
  };
in {
  network.description = "IOHK Infra CI";
  network.enableRollback = true;
} // nodes
