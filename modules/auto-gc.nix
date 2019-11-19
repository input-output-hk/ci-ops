{ pkgs, lib, ... }:

let
  minFree = 10000;
  maxFree = 20000;
in {
  nix = {
    extraOptions = ''
      # Try to ensure between ${toString minFree}M and ${toString maxFree}M of free space by
      # automatically triggering a garbage collection if free
      # disk space drops below a certain level during a build.
      min-free = ${toString (minFree * 1024 * 1024)}
      max-free = ${toString (maxFree * 1024 * 1024)}

      auto-optimise-store = true
    '';
    gc = {
      automatic = true;
      dates = "*:15:00";
      options = ''--max-freed "$((30 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | ${pkgs.gawk}/bin/awk '{ print $4 }')))"'';
    };
  };
}
