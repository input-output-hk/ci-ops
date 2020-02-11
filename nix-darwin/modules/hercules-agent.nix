{ config, lib, pkgs, ... }:
let
  sources = import ../../nix/sources.nix;
  herculesDarwinPkg = (import sources.hercules-ci-agent-darwin {}).hercules-ci-agent;
  herculesHome = "/var/lib/hercules-ci-agent";
in with lib; {
  services.hercules-ci-agent = {
    enable = true;
    package = herculesDarwinPkg;
  };

  # Fix up ownership and perms on secrets.  We use applications
  # so this occurs between creating users and launchd scripts
  system.activationScripts.applications.text = ''
    mkdir -p ${herculesHome}/secrets
    chown -R hercules-ci-agent ${herculesHome}
    chmod -R 0600 ${herculesHome}/secrets
  '';
}
