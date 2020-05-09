{ pkgs, lib, config, ... }:

let
  cfg = config.services.hydra-crystal-notifier;

  inherit (lib)
    mkIf mkOption types mkEnableOption concatStringsSep optionals optionalAttrs;
in {
  options = {
    services.hydra-crystal-notifier = {
      enable = mkEnableOption "hydra crystal notifier";

      package = mkOption {
        type = types.package;
        default = (import ../. {}).packages.hydra-crystal-notifier;
        defaultText = "hydra-crystal-notifier";
        description = " The hydra crystal notifier package to be used";
      };

      logLevel = mkOption {
        type = types.enum [ "UNKNOWN" "DEBUG" "INFO" "WARN" "ERROR" "FATAL" ];
        default = "INFO";
        description = ''
          The log level for the hydra crystal notifier service. Valid levels are:
          UNKNOWN DEBUG INFO WARN ERROR FATAL.
        '';
      };

      # TODO: add a different logging target with the new log module in crystal 0.34
      #logFile = mkOption {
      #  type = types.str;
      #  default = "/var/lib/hydra/notification-debug.log";
      #  description = "The default path an alternate log file if not logging to STDOUT";
      #};

      mockMode = mkOption {
        type = types.enum [ "TRUE" "FALSE" ];
        default = "FALSE";
        description = "If set to TRUE, any API calls won't only be logged, but not actually made";
      };

      configFile = mkOption {
        type = types.str;
        default = "/var/lib/hydra/github-notify.conf";
        description = "The default path to the hydra crystal notifier config file";
      };

      baseUri = mkOption {
        type = types.str;
        default = "https://hydra.iohk.io";
        description = "The default base URI path for composing hydra link references";
      };

      dbUser = mkOption {
        type = types.str;
        default = "";
        description = ''
          The default database user to connect to hydra postgres with.
          NOTE: This works with a blank string when deploying to the hydra
                server and run as a service with the hydra user.
        '';
      };

      dbDatabase = mkOption {
        type = types.str;
        default = "hydra";
        description = "The default database to connect to hydra postgres with";
      };

      dbHost = mkOption {
        type = types.str;
        default = "/run/postgresql";
        description = "The default host to connect to hydra postgres with";
      };

      notifyUrl = mkOption {
        type = types.str;
        default = "DEFAULT";
        description = ''
          The default notify URL to use host to connect to hydra postgres with.
          If "DEFAULT" is used, the hydra crystal notifier will use its default url.
          If any string other than "DEFAULT" is provided, that will be directly used
          as the url.  Note that crystal string interpolation `#{...}` can be provided.

          Examples are:

          # Live github status submission url
          "https://api.github.com/repos/#{m["owner"]}/#{m["repo"]}/statuses/#{rev}"

          # Test submissions on a non-github test server
          "http://<HOST>:<PORT>/api.github.com/repos/#{m["owner"]}/#{m["repo"]}/statuses/#{rev}"

          # Test submissions on github on a throw-away branch with a test commit
          "https://api.github.com/repos/<OWNER>/<REPO>/statuses/<COMMIT>"
        '';
      };

      apiPeriod = mkOption {
        type = types.int;
        default = 3600;
        description = ''
          The API time period in seconds used by github prior to API refresh.
          This value is used to calculate a damping function that is applied
          to a time-averaging API rate limit calculation.
        '';
      };

      notifiedTtl = mkOption {
        type = types.int;
        default = 8 * 3600;
        description = ''
          The default time period used for maintaining repo-commit key state
          values in memory before they expire.  Default build expirations are
          typically set to 8 hours, which is also the default for this parameter.
        '';
      };

      maintChecks = mkOption {
        type = types.int;
        default = 300;
        description = ''
          The default time period to perform a maintenance check of the
          repo-commit key state held in memory and expire any aged key value
          pairs, followed by logging a status update to the logger.
        '';
      };

      commitRateLimit = mkOption {
        type = types.int;
        default = 10;
        description = ''
          The default value to rate limit API notifications to github at on a
          repo-commit key basis.  Only one API call may happen within this time
          period per repo-commit.  Final notifications for aggregate or target
          jobs are exempted from this limit so that status checks will receive
          a final update successfully.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hydra-crystal-notifier = {
      wantedBy = [ "multi-user.target" ];
      after = [ "postgresql.service" ];
      startLimitIntervalSec = 0;

      script = ''
        ${cfg.package}/bin/hydra-crystal-notifier
      '';

      serviceConfig = {
        User = "hydra";
        Group = "hydra";
        Restart = "always";
        RestartSec = "10s";
      };

      environment = {
        LOG_LEVEL = cfg.logLevel;
        LOG_FILE = "/var/lib/hydra/notification-debug.log";
        MOCK_MODE = cfg.mockMode;
        CFG_FILE = cfg.configFile;
        BASE_URI = cfg.baseUri;
        DB_USER = cfg.dbUser;
        DB_DATABASE = cfg.dbDatabase;
        DB_HOST = cfg.dbHost;
        NOTIFY_URL = cfg.notifyUrl;
        API_PERIOD = toString cfg.apiPeriod;
        NOTIFIED_TTL = toString cfg.notifiedTtl;
        MAINT_CHECKS = toString cfg.maintChecks;
        COMMIT_RATE_LIMIT = toString cfg.commitRateLimit;
      };
    };
  };
}
