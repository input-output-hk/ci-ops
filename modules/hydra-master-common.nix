{ config, pkgs, lib, ... }:

with lib; {
  nix = {
    # autoOptimiseStore = true;
    extraOptions = ''
      allowed-uris = ${toString (lib.concatMap
        (r: ["https://github.com/${r}" "https://api.github.com/repos/${r}"])
        [
          "LnL7/nix-darwin"
          "NixOS"
          "edolstra"
          "input-output-hk"
          "justinwoo/easy-purescript-nix"
          "moretea/yarn2nix"
          "mozilla/nixpkgs-mozilla"
          "numtide/flake-utils"
          "divnix"
        ]
      )}

      # Max of 2 hours to build any given derivation on Linux.
      # See ../nix-darwin/modules/basics.nix for macOS.
      timeout = 7200

      connect-timeout = 10
    '';
    binaryCaches = mkForce [ "https://cache.nixos.org" ];
  };

  # let's auto-accept fingerprints on first connection
  programs.ssh.extraConfig = ''
    StrictHostKeyChecking no
  '';

  services.hydra = {
    enable = true;
    port = 8080;
    useSubstitutes = true;
    notificationSender = "hi@iohk.io";
    logo = ./hydra/iohk-logo.png;
  };

  services.postgresql = {
    package = pkgs.postgresql_13;
    dataDir = "/var/db/postgresql-${config.services.postgresql.package.psqlSchema}";
    settings = {
      # DB Version: 13
      # OS Type: linux
      # DB Type: web
      # Total Memory (RAM): 8 GB
      # CPUs num: 4
      # Connections num: 200
      # Data Storage: ssd
      max_connections = 200;
      shared_buffers = "2GB";
      effective_cache_size = "6GB";
      maintenance_work_mem = "512MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "5242kB";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
      max_worker_processes = 4;
      max_parallel_workers_per_gather = 2;
      max_parallel_workers = 4;
      max_parallel_maintenance_workers = 2;
    };
  };

  systemd.services.hydra-evaluator.path = [ pkgs.gawk ];
  systemd.services.hydra-queue-runner.serviceConfig = {
    ExecStart = mkForce "@${config.services.hydra.package}/bin/hydra-queue-runner hydra-queue-runner -v";
  };
  systemd.services.hydra-manual-setup = {
    description = "Create Keys for Hydra";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      path = config.systemd.services.hydra-init.environment.PATH;
    };
    wantedBy = [ "multi-user.target" ];
    requires = [ "hydra-init.service" ];
    after = [ "hydra-init.service" ];
    environment = builtins.removeAttrs config.systemd.services.hydra-init.environment ["PATH"];
    script = ''
      if [ ! -e ~hydra/.setup-is-complete ]; then
        # create signing keys
        /run/current-system/sw/bin/install -d -m 551 /etc/nix/hydra.iohk.io-1
        /run/current-system/sw/bin/nix-store --generate-binary-cache-key hydra.iohk.io-1 /etc/nix/hydra.iohk.io-1/secret /etc/nix/hydra.iohk.io-1/public
        /run/current-system/sw/bin/chown -R hydra:hydra /etc/nix/hydra.iohk.io-1
        /run/current-system/sw/bin/chmod 440 /etc/nix/hydra.iohk.io-1/secret
        /run/current-system/sw/bin/chmod 444 /etc/nix/hydra.iohk.io-1/public
        # done
        touch ~hydra/.setup-is-complete
      fi
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx.enable = true;
}
