{ config, lib, pkgs, ... }:

let
  keys = "/Users/nixos/buildkite";
  cfg = config.services.buildkite-services-darwin;
in with lib; {
  options = {
    services.buildkite-services-darwin = {
      metadata = mkOption {
        type = types.str;
        default = "system=x86_64-darwin";
        description = ''
          Metadata associated with a buildkite agent.
        '';
        example = "system=x86_64-darwin";
      };
    };
  };

  config = {
    services.buildkite-agent = {
      enable = true;
      package = pkgs.buildkite-agent;
      runtimePackages = with pkgs; [
        bash gnutar gzip bzip2 xz
        git git-lfs
        nix
      ];
      meta-data = cfg.metadata;
      tokenPath = "${keys}/buildkite_token_*";
      openssh.privateKeyPath = "${keys}/buildkite-ssh-iohk-devops-private";
      openssh.publicKeyPath = "${keys}/buildkite-ssh-iohk-devops-public";
      hooks.pre-command = ''
        creds=${keys}/buildkite_aws_creds_*
        if [ -e $creds ]; then
          source $creds
        else
          (>&2 echo "$creds doesn't exist. The build is going to fail.")
        fi
      '';
      hooks.environment = ''
        # Provide a minimal build environment
        export NIX_BUILD_SHELL="/run/current-system/sw/bin/bash"
        export NIX_PATH="nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        # /usr/bin and /usr/sbin are added For iconutil, security, pkgutil, etc.
        # Required for daedalus installer build,
        # or any build which expects to have apple tools.
        export PATH="$PATH:/usr/bin:/usr/sbin"
      '';
      extraConfig = ''
        no-pty=true
        # debug=true
        # priority=9
      '';
      preCommands = ''
        source /var/lib/buildkite-agent/signing.sh
        security unlock-keychain -p "$SIGNING" /var/lib/buildkite-agent/ci-signing.keychain-db
      '';
    };

    # this is required to actually create the users -- i don't know why
    users.knownUsers = [ "buildkite-agent" ];
    users.knownGroups = [ "buildkite-agent" ];
    users.users.buildkite-agent = {
      uid = 727;
      gid = 727;
    };
    users.groups.buildkite-agent.gid = 727;

    # Fix up group membership and perms on secrets directory.
    # Ensure that buildkite-agent home directory exists with correct
    # permissions. We use applications so this occurs between creating users
    # and launchd scripts
    system.activationScripts.applications.text = ''
      dseditgroup -o edit -a nixos -t user buildkite-agent
      mkdir -p ${keys}
      chgrp -R buildkite-agent ${keys}
      chmod -R o-rx ${keys}

      mkdir -p ${config.users.users.buildkite-agent.home}
      chown buildkite-agent:admin ${config.users.users.buildkite-agent.home}
      chmod 770 ${config.users.users.buildkite-agent.home}
    '';
  };
}
