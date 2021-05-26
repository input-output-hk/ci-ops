{ resources, config, pkgs, lib, ... }:

with lib;

let
  commonBuildMachineOpt = {
    speedFactor = 1;
    sshKey = "/etc/nix/id_buildfarm";
    sshUser = "root";
    systems = [ "i686-linux" "x86_64-linux" ];
    supportedFeatures = [ "kvm" "nixos-test" "big-parallel" ];
  };
  mkLinux = hostName: commonBuildMachineOpt // {
    inherit hostName;
    maxJobs = 10;
    speedFactor = 1;
  };
  mkMac = hostName: commonBuildMachineOpt // {
    inherit hostName;
    maxJobs = 8;
    systems = [ "x86_64-darwin" ];
    sshUser = "builder";
    supportedFeatures = [ "big-parallel" ];
  };
  localMachine = {
    hostName = "localhost";
    mandatoryFeatures = [ "local" ];
    systems = [ "x86_64-linux" "i686-linux" ];
    maxJobs = 8;
  };
  mkGithubStatus = { jobset, inputs ? jobset }: ''
    <githubstatus>
      jobs = Cardano:${jobset}.*:required
      inputs = ${inputs}
      excludeBuildFromContext = 1
      useShortContext = 1
    </githubstatus>
  '';
  mkStatusBlocks = concatMapStringsSep "" mkGithubStatus;
  mkGithubStatusConfig = ''
    <github_authorization>
      input-output-hk = token ${builtins.readFile ../secrets/github_token}
    </github_authorization>

    ${mkStatusBlocks [
      # the shorter names must be later in the list, or the regex will be greedy and never check the longer names
      { jobset = "cardano-addresses"; }
      { jobset = "cardano-base"; }
      { jobset = "cardano-benchmarking"; }
      { jobset = "cardano-byron-proxy"; }
      { jobset = "cardano-db-sync"; }
      { jobset = "cardano-explorer-app"; }
      { jobset = "cardano-faucet"; }
      { jobset = "cardano-graphql"; }
      { jobset = "cardano-ledger-specs"; }
      { jobset = "cardano-ledger"; }                    # Below cardano-ledger-specs for regex match
      { jobset = "cardano-node-p2p"; }
      { jobset = "cardano-node"; }                      # Below cardano-node-p2p for regex match
      { jobset = "cardano-ops"; }
      { jobset = "cardano-prelude"; }
      { jobset = "cardano-rest"; }
      { jobset = "cardano-rosetta"; }
      { jobset = "cardano-rt-view"; }
      { jobset = "cardano-shell"; }
      { jobset = "cardano-wallet"; }
      { jobset = "cardano"; }                           # Below all other cardano-.* jobsets for regex match
      { jobset = "ci-ops"; }
      { jobset = "decentralized-software-updates"; }
      { jobset = "haskell-nix"; }
      { jobset = "hydra-poc"; }
      { jobset = "iohk-monitoring"; }
      { jobset = "iohk-nix"; }
      { jobset = "iohk-ops"; inputs = "jobsets"; }
      { jobset = "jormungandr"; }
      { jobset = "kes-mmm-sumed25519"; }
      { jobset = "log-classifier"; }
      { jobset = "offchain-metadata-tools"; }
      { jobset = "ouroboros-network"; }
      { jobset = "plutus"; }
      { jobset = "rust-libs"; }
      { jobset = "smash"; }
      { jobset = "tools"; }
      { jobset = "voting-tools"; }
    ]}

    # DEVOPS-1208 This CI status for cardano-sl is needed while the
    # Daedalus Windows installer is built on AppVeyor or Buildkite
    <githubstatus>
      jobs = Cardano:cardano-sl.*:daedalus-mingw32-pkg
      inputs = cardano
      excludeBuildFromContext = 1
      useShortContext = 1
    </githubstatus>
    <githubstatus>
      jobs = Cardano:daedalus.*:tests\..*
      inputs = daedalus
      excludeBuildFromContext = 1
      useShortContext = 1
    </githubstatus>
  '';
  githubStatusConfig = pkgs.writeText "github-notify.conf"  mkGithubStatusConfig;

in {
  environment.etc = lib.singleton {
    target = "nix/id_buildfarm";
    source = ../secrets/id_buildfarm;
    uid = config.ids.uids.hydra-queue-runner;
    gid = config.ids.gids.hydra;
    mode = "0400";
  };
  programs.ssh.extraConfig = lib.mkAfter ''
    Host sarov
    Hostname 192.168.20.20
    Port 2200
    Host mac-mini-1
    Hostname 192.168.20.21
    Port 2200
    Host mac-mini-2
    Hostname 192.168.20.22
    Port 2200
  '';

  nix = {
    distributedBuilds = true;
    # localMachine removed to prevent GC roots accumulation on hydra
    buildMachines = [
      (mkLinux "packet-ipxe-1.ci.iohkdev.io")
      (mkLinux "packet-ipxe-2.ci.iohkdev.io")
      (mkLinux "packet-ipxe-3.ci.iohkdev.io")

      # Tmp extra builders
      (mkLinux "packet-ipxe-5.ci.iohkdev.io")

      ((mkMac "mac-mini-1") // { speedFactor = 2; })
      ((mkMac "mac-mini-2") // { speedFactor = 2; })
    ];
    binaryCaches = mkForce [ "https://cache.nixos.org" "https://hydra.iohk.io" ];
  };

  systemd.services.hydra-evaluator.environment.GC_INITIAL_HEAP_SIZE = toString (1024*1024*1024*5); # 5gig
  services.hydra = {
    hydraURL = "https://hydra.iohk.io";
    package = pkgs.callPackage ../pkgs/hydra.nix {};
    # max output is 4GB because of amis
    # auth token needs `repo:status`
    extraConfig = ''
      max_output_size = 4294967296
      evaluator_max_memory_size = 16384
      max_db_connections = 50

      max_concurrent_evals = 6

      store_uri = s3://iohk-nix-cache?secret-key=/etc/nix/hydra.iohk.io-1/secret&log-compression=br&region=eu-central-1
      server_store_uri = https://iohk-nix-cache.s3-eu-central-1.amazonaws.com/
      binary_cache_public_uri = https://iohk-nix-cache.s3-eu-central-1.amazonaws.com/
      log_prefix = https://iohk-nix-cache.s3-eu-central-1.amazonaws.com/
      upload_logs_to_binary_cache = true

      ${mkGithubStatusConfig}
    '';
  };
  services.grafana = {
    enable = true;
    users.allowSignUp = true;
    domain = "hydra.ci.iohkdev.io";
    rootUrl = "%(protocol)ss://%(domain)s/grafana/";
    extraOptions = {
      AUTH_GOOGLE_ENABLED = "true";
      AUTH_GOOGLE_CLIENT_ID = "778964826061-5v0m922g1qcbc1mdtpaf8ffevlso2v7p.apps.googleusercontent.com";
      AUTH_GOOGLE_CLIENT_SECRET = builtins.readFile ../secrets/google_oauth_hydra_grafana.secret;
    };
  };
  services.hydra-crystal-notify.configFile = toString githubStatusConfig;

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  environment.systemPackages = with pkgs; [ goaccess ];
  services.nginx = {
    virtualHosts = {
      "hydra.ci.iohkdev.io" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "hydra.iohk.io" ];
        locations."/".extraConfig = ''
          proxy_pass http://127.0.0.1:8080;
          proxy_set_header Host $host;
          proxy_set_header REMOTE_ADDR $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
        locations."~ /(nix-cache-info|.*\\.narinfo|nar/*)".extraConfig = ''
          return 301 https://iohk-nix-cache.s3-eu-central-1.amazonaws.com$request_uri;
        '';
        locations."/graph/".extraConfig = ''
          proxy_pass http://127.0.0.1:8081;
        '';
        locations."/grafana/".extraConfig = ''
          proxy_pass http://localhost:3000/;
        '';
      };
    };
    commonHttpConfig = ''
      server_names_hash_bucket_size 64;
      keepalive_timeout   70;
      gzip            on;
      gzip_min_length 1000;
      gzip_proxied    expired no-cache no-store private auth;
      gzip_types      text/plain application/xml application/javascript application/x-javascript text/javascript text/xml text/css;
      log_format x-fwd '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status $body_bytes_sent '
                       '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';
      access_log syslog:server=unix:/dev/log x-fwd;
    '';
  };
}
