{ pkgs, lib, name, config, resources, ... }:
let
  inherit (import ../../globals.nix) domain packet;
  inherit (lib) mkDefault;
in {
  deployment.targetEnv = "packet";

  imports = [ ../../modules/cloud.nix ];
  deployment.packet = {
    keyPair = resources.packetKeyPairs.global;
    inherit (packet.credentials) accessKeyId project;
  };

  nixpkgs.localSystem.system = "x86_64-linux";
  networking.hostName = mkDefault name;
  node = { fqdn = "${name}.${domain}"; };
}
