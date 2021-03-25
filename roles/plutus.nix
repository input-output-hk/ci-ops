{ pkgs, lib, config, resources, name, ... }: let
  ssh-keys = config.services.ssh-keys;
in {
  imports = [];
  users.extraUsers.root.openssh.authorizedKeys.keys = ssh-keys.devOps ++ ssh-keys.plutus-developers;
  environment.etc."mdadm.conf".text = ''
    MAILADDR root
  '';
}
