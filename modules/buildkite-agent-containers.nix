{ config, lib, pkgs, name, ... }:
let
  cfg = config.services.buildkite-containers;
  ssh-keys = config.services.ssh-keys;
in with lib;
{
  imports = [
    # GC only from the host to avoid duplicating GC in containers
    ./auto-gc.nix
    # Docker module required in both the host and guest containers
    ./docker-builder.nix
  ];

  options = {
    services.buildkite-containers = {
      hostIdSuffix = mkOption {
        type = types.str;
        default = "1";
        description = ''
          A host identifier suffix which is typically a CI server number and is used
          as part of the container name.  Container names are limited to 7 characters,
          so the default naming convention is ci''${hostIdSuffix}-''${containerNum}.
          An example container name, using a hostIdSuffix of 2 for example, may then
          be ci2-4, indicating a 4th CI container on a 2nd host CI server.
        '';
        example = "1";
      };

      containerList = mkOption {
        type = types.listOf types.attrs;
        default = [
          { containerName = "ci${cfg.hostIdSuffix}-1"; guestIp = "10.254.1.11"; prio = "9"; }
          { containerName = "ci${cfg.hostIdSuffix}-2"; guestIp = "10.254.1.12"; prio = "8"; }
          { containerName = "ci${cfg.hostIdSuffix}-3"; guestIp = "10.254.1.13"; prio = "7"; }
          { containerName = "ci${cfg.hostIdSuffix}-4"; guestIp = "10.254.1.14"; prio = "6"; }
        ];
        description = ''
          This parameter allows container customization on a per server basis.
          The default is for 4 buildkite containers.
          Note that container names cannot be more than 7 characters.
        '';
        example = ''
          [ { containerName = "ci1-1"; guestIp = "10.254.1.11"; tags = { system = "x86_64-linux"; queue = "custom"; }; } ];
        '';
      };

      weeklyCachePurge = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to delete the shared /cache dir weekly";
      };

      weeklyCachePurgeOnCalendar = mkOption {
        type = types.str;
        default = "Sat *-*-* 20:00:00";
        description = "The default weekly day and time to perform a weekly /cache dir and swap purge, if enabled.  Uses systemd onCalendar format.";
      };
    };
  };

  config = let
    createBuildkiteContainer = { containerName                           # The desired container name
                               , hostIp ? "10.254.1.1"                   # The IPv4 host virtual eth nic IP
                               , guestIp ? "10.254.1.11"                 # The IPv4 container guest virtual eth nic IP
                               , tags ? { system = "x86_64-linux"; }     # Agent metadata customization
                               , prio ? null                             # Agent priority
                               }: {
      name = containerName;
      value = {
        autoStart = true;
        bindMounts = {
          "/run/keys" = {
            hostPath = "/run/keys";
          };
          "/var/lib/buildkite-agent/hooks" = {
            hostPath = "/var/lib/buildkite-agent/hooks";
          };
          "/cache" = {
            hostPath = "/cache";
            isReadOnly = false;
          };
        };
        privateNetwork = true;
        hostAddress = hostIp;
        localAddress = guestIp;
        config = {
          imports = [
            ./nix_nsswitch.nix
            # Docker module required in both the host and guest containers
            ./docker-builder.nix
            # common.nix doesn't get automatically added to containers like to nodes
            ./common.nix
          ];
          services.monitoring-exporters.enable = false;
          services.ntp.enable = mkForce false;

          systemd.services.buildkite-agent.serviceConfig = {
            ExecStart = mkForce "${pkgs.buildkite-agent}/bin/buildkite-agent start --config /var/lib/buildkite-agent/buildkite-agent.cfg";
            LimitNOFILE = 1024 * 512;
          };

          services.buildkite-agents.iohk = {
            name   = name + "-" + containerName;
            privateSshKeyPath      = "/run/keys/buildkite-ssh-iohk-devops-private";
            tokenPath              = "/run/keys/buildkite-token";
            inherit tags;
            runtimePackages        = with pkgs; [
               bash gnutar gzip bzip2 xz
               git git-lfs
               nix
            ];

            hooks.environment = ''
              # Provide a minimal build environment
              export NIX_BUILD_SHELL="/run/current-system/sw/bin/bash"
              export PATH="/run/current-system/sw/bin:$PATH"

              # Provide NIX_PATH, unless it's already set by the pipeline
              if [ -z "''${NIX_PATH:-}" ]; then
                  # see ci-ops/modules/common.nix (system.extraSystemBuilderCmds)
                  export NIX_PATH="nixpkgs=/run/current-system/nixpkgs"
              fi

              # load S3 credentials for artifact upload
              source /var/lib/buildkite-agent/hooks/aws-creds

              # load extra credentials for user services
              source /var/lib/buildkite-agent/hooks/buildkite-extra-creds
            '';
            hooks.pre-command = ''
              # Clean out the state that gets messed up and makes builds fail.
              rm -rf ~/.cabal
            '';
            hooks.pre-exit = ''
              # Clean up the scratch and tmp directories
              rm -rf /scratch/* &> /dev/null || true
            '';
            extraConfig = ''
              git-clean-flags="-ffdqx"
              ${if prio != null then "priority=${prio}" else ""}
            '';
          };
          users.users.buildkite-agent-iohk = {
            isSystemUser = true;
            # To ensure buildkite-agent-iohk user sharing of keys in guests
            uid = 10000;
            extraGroups = [
              "keys"
              "docker"
            ];
          };

          # Globally enable stack's nix integration so that stack builds have
          # the necessary dependencies available.
          environment.etc."stack/config.yaml".text = ''
            nix:
              enable: true
          '';

          systemd.services.buildkite-agent-custom = {
            wantedBy = [ "buildkite-agent.service" ];
            script = ''
              mkdir -p /build /scratch
              chown -R buildkite-agent:nogroup /build /scratch
            '';
            serviceConfig = {
              Type = "oneshot";
            };
          };
        };
      };
    };
  in {
    users.users.root.openssh.authorizedKeys.keys = ssh-keys.ciInfra;
    #services.buildkite-agents.package = pkgs.buildkite-agent;

    # To go on the host -- and get shared to the container(s)
    deployment.keys = {
      aws-creds = {
        keyFile = ../secrets/buildkite-hook;
        destDir = "/var/lib/buildkite-agent/hooks";
        user    = "buildkite-agent-iohk";
        permissions = "0770";
      };

      # Project-specific credentials to install on Buildkite agents.
      buildkite-extra-creds = {
        keyFile = ../secrets/buildkite-hook-extra-creds.sh;
        destDir = "/var/lib/buildkite-agent/hooks";
        user    = "buildkite-agent-iohk";
        permissions = "0770";
      };

      # SSH keypair for buildkite-agent user
      buildkite-ssh-private = {
        keyFile = ../secrets/buildkite-ssh;
        user    = "buildkite-agent-iohk";
      };
      buildkite-ssh-public = {
        keyFile = ../secrets/buildkite-ssh.pub;
        user    = "buildkite-agent-iohk";
      };

      # SSH keypair for buildkite-agent user (iohk-devops on Github)
      buildkite-ssh-iohk-devops-private = {
        keyFile = ../secrets/buildkite-iohk-devops-ssh;
        user    = "buildkite-agent-iohk";
      };

      # GitHub deploy key for input-output-hk/hackage.nix
      buildkite-hackage-ssh-private = {
        keyFile = ../secrets/buildkite-hackage-ssh;
        user    = "buildkite-agent-iohk";
      };

      # GitHub deploy key for input-output-hk/stackage.nix
      buildkite-stackage-ssh-private = {
        keyFile = ../secrets/buildkite-stackage-ssh;
        user    = "buildkite-agent-iohk";
      };

      # GitHub deploy key for input-output-hk/haskell.nix
      # (used to update gh-pages documentation)
      buildkite-haskell-dot-nix-ssh-private = {
        keyFile = ../secrets/buildkite-haskell-dot-nix-ssh;
        user    = "buildkite-agent-iohk";
      };

      # GitHub deploy key for input-output-hk/cardano-wallet
      # created with: ssh-keygen -t ed25519 -C "buildkite cardano-wallet" -f secrets/buildkite-cardano-wallet-ssh
      buildkite-cardano-wallet-ssh-private = {
        keyFile = ../secrets/buildkite-cardano-wallet-ssh;
        user    = "buildkite-agent-iohk";
      };

      # API Token for BuildKite
      buildkite-token = {
        keyFile = ../secrets/buildkite_token;
        user    = "buildkite-agent-iohk";
      };

      # DockerHub password/token (base64-encoded in json)
      dockerhub-auth = {
        keyFile = ../secrets/dockerhub-auth-config.json;
        user    = "buildkite-agent-iohk";
      };

      # Catalyst keystore
      "catalyst.keystore" = {
        keyFile = ../secrets/catalyst.keystore;
        user    = "buildkite-agent-iohk";
      };

      # Catalyst build spec
      "catalyst-android-build.json" = {
        keyFile = ../secrets/catalyst-android-build.json;
        user    = "buildkite-agent-iohk";
      };

      # Catalyst env vars
      "catalyst-env.sh" = {
        keyFile = ../secrets/catalyst-env.sh;
        user    = "buildkite-agent-iohk";
      };

      # Catalyst sentry spec
      "catalyst-sentry.properties" = {
        keyFile = ../secrets/catalyst-sentry.properties;
        user    = "buildkite-agent-iohk";
      };
    };

    system.activationScripts.cacheDir = {
      text = ''
        mkdir -p /cache
        chown -R buildkite-agent-iohk:nogroup /cache || true
      '';
      deps = [];
    };

    users.users.buildkite-agent-iohk = {
      home = "/var/lib/buildkite-agent";
      isSystemUser = true;
      createHome = true;
      # To ensure buildkite-agent-iohk user sharing of keys in guests
      uid = 10000;
    };

    environment.systemPackages = [ pkgs.nixos-container ];
    networking.nat.enable = true;
    networking.nat.internalInterfaces = [ "ve-+" ];
    networking.nat.externalInterface = "bond0";

    services.fstrim.enable = true;
    services.fstrim.interval = "daily";

    systemd.services.weekly-cache-purge = mkIf cfg.weeklyCachePurge {
      script = ''
        # Temporarily clear the cache manually during no buildkite builds
        #rm -rf /cache/* || true
        ${pkgs.utillinux}/bin/swapoff -a
        ${pkgs.utillinux}/bin/swapon -a
      '';
    };

    systemd.timers.weekly-cache-purge = mkIf cfg.weeklyCachePurge {
      timerConfig = {
        Unit = "weekly-cache-purge.service";
        OnCalendar = cfg.weeklyCachePurgeOnCalendar;
      };
      wantedBy = [ "timers.target" ];
    };

    containers = builtins.listToAttrs (map createBuildkiteContainer cfg.containerList);
  };
}
