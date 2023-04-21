{ config, lib, pkgs, ... }:

with lib;

let
  ssh-keys = import ../../lib/ssh-keys.nix lib;

  allowedKeys = ssh-keys.allKeysFrom (ssh-keys.remoteBuilderKeys // ssh-keys.devOps);

  environment = concatStringsSep " "
    [ "NIX_REMOTE=daemon"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
in

{
  users.knownUsers = [ "builder" ];
  users.users.builder = {
    uid = 502;
    gid = 20;  # staff
    description = "Hydra";
    home = "/Users/builder";
    shell = "/bin/bash";
  };

  nix.settings.trusted-users = [ "root" "builder" ];

  # Create a ~/.bashrc containing source /etc/profile
  # (bash doesn't source the ones in /etc for non-interactive
  # shells and that breaks everything nix)
  system.activationScripts.postActivation.text = ''
    mkdir -p /Users/builder
    echo "source /etc/profile" > /Users/builder/.bashrc
    chown builder: /Users/builder/.bashrc
    dseditgroup -o edit -a builder -t user com.apple.access_ssh
  '';

  environment.etc."per-user/builder/ssh/authorized_keys".text =
    concatMapStringsSep "\n" (key: ''command="${environment} ${config.nix.package}/bin/nix-store --serve --write" ${key}'') allowedKeys + "\n";
}
