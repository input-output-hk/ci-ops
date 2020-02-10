{ pkgs, lib, ... }:

{
  imports = [
    ./modules/hydra-base.nix
    ./modules/hydra-master-main.nix
    ./modules/auto-gc.nix
    ./modules/hydra-master-wireguard.nix
    ./modules/nix_nsswitch.nix
    <nixpkgs/nixos/modules/virtualisation/amazon-image.nix>
  ];
  boot.loader.grub.device = lib.mkForce "/dev/nvme0n1";
  _module.args.name = "hydra";
  services.sshd.enable = true;
  boot.loader.grub.splashImage = null;
  services.postgresql.superUser = "root";
  services.grafana.enable = true;
  nix.binaryCaches = lib.mkForce [ "https://cache.nixos.org" ];
  networking.firewall.allowedTCPPorts = [ 80 443 9100 9113 ];
}
