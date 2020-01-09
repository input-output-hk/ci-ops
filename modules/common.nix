{ pkgs, lib, name, config, resources, ... }:
let
  sshKeys =
    import ((import ../nix/sources.nix).iohk-ops + "/lib/ssh-keys.nix") {
      inherit lib;
    };
  inherit (sshKeys) allKeysFrom devOps;
  devOpsKeys = allKeysFrom devOps;
in {

  imports = [ ./aws.nix ./monitoring-exporters.nix ];

  networking.hostName = name;

  environment.systemPackages = with pkgs; [
    bat
    git
    graphviz
    htop
    iptables
    jq
    lsof
    mosh
    ncdu
    sysstat
    sqliteInteractive
    tcpdump
    tig
    tree
    vim
  ];

  environment.variables.TERM = "xterm-256color";

  boot.kernel.sysctl = {
    ## DEVOPS-592
    "kernel.unprivileged_bpf_disabled" = 1;
  };

  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = devOpsKeys;

  users.users.debug = {
    isNormalUser = true;
    hashedPassword = "$6$1Ys4mXwnwyfAWnPf$OjsZ.srTzlDcPEZ.PZyFVjEfZF6k9T8qFLXbP5Ebw54dR1KGZLUrIWOv4t.gHmVYh8o79cPVDevLhhn7PH40W/";
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = true;

  services = {
    monitoring-exporters.graylogHost = "monitoring:5044";

    nginx.mapHashBucketSize = 128;

    openssh = {
      passwordAuthentication = false;
      authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
      extraConfig = lib.mkOrder 9999 ''
        Match User root
          AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2 /etc/ssh/authorized_keys.d/%u
      '';
    };

    ntp.enable = true;
    cron.enable = true;
  };

  nix = rec {
    # use nix sandboxing for greater determinism
    useSandbox = true;

    # make sure we have enough build users
    nrBuildUsers = 32;

    # if our hydra is down, don't wait forever
    extraOptions = ''
      connect-timeout = 10
      http2 = true
      show-trace = true
    '';

    # use all cores
    buildCores = 0;

    nixPath = [ "nixpkgs=/run/current-system/nixpkgs" ];

    # use our hydra builds
    trustedBinaryCaches = [ "https://cache.nixos.org" "https://hydra.iohk.io" ];
    binaryCaches = trustedBinaryCaches;
    binaryCachePublicKeys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };

  system.extraSystemBuilderCmds = ''
    ln -sv ${(import ../nix { }).path} $out/nixpkgs
  '';

  # Mosh
  networking.firewall.allowedUDPPortRanges = [{
    from = 60000;
    to = 61000;
  }];

  deployment.ec2.securityGroups = [
    resources.ec2SecurityGroups."allow-graylog-nodes-${config.node.region}"
  ];
}
