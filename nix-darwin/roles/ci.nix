{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/basics.nix
    ../modules/hydra-slave.nix
    ../modules/buildkite-agent.nix
    #../modules/hercules-agent.nix
  ];
  services.buildkite-services-darwin.metadata = "system=x86_64-darwin,queue=default,queue=core-tech";
}
