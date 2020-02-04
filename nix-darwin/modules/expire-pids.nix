# This module is related to: https://github.com/NixOS/nix/issues/3294
{ config, lib, pkgs, ... }:
{
  imports = [ ../services/expire-pids.nix ];

  # This expire pids service is run on 15 minute intervals
  nix.expire-pids = {
    enable = true;
    targetProcess = "[n]ix-daemon";
    ppidExclusion = 1;
    threshold = (8 * 3600) + 1;
    numberOfProcesses = 10000;
  };
}
