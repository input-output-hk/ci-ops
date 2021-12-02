{ config, pkgs, lib, ... }:
let
  hostname = "bors-ng.aws.iohkdev.io";
  keysDir = "/var/lib/keys";
in {
  imports = [ ../modules/bors-ng-service.nix ];

  deployment.keys = {
    bors-ng-secret-key-base = {
      keyFile = ../secrets/bors-ng-secret-key-base;
      destDir = keysDir;
      user = "bors-ng";
    };
    bors-ng-github-client-secret = {
      keyFile = ../secrets/bors-ng-github-client-secret;
      destDir = keysDir;
      user = "bors-ng";
    };
    "bors-ng-github-integration.pem" = {
      keyFile = ../secrets/bors-ng-github-integration.pem;
      destDir = keysDir;
      user = "bors-ng";
    };
    bors-ng-github-webhook-secret = {
      keyFile = ../secrets/bors-ng-github-webhook-secret;
      destDir = keysDir;
      user = "bors-ng";
    };
  };

  services.bors-ng = {
    enable = true;
    dockerImage = "borsng/bors-ng:latest";
    databaseURL = "postgresql://bors_ng:bors_ng@localhost:5432/bors_ng";
    publicHost = hostname;
    secretKeyBaseFile = "${keysDir}/bors-ng-secret-key-base";
    github = {
      clientID = "Iv1.17382ed95b58d1a8";
      clientSecretFile = "${keysDir}/bors-ng-github-client-secret";
      integrationID = 17473;
      integrationPEMFile = "${keysDir}/bors-ng-github-integration.pem";
      webhookSecretFile = "${keysDir}/bors-ng-github-webhook-secret";
    };
  };
  systemd.services.bors-ng = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    ensureUsers = [
      {
        name = "bors_ng";
        ensurePermissions = {
          "DATABASE bors_ng" = "ALL PRIVILEGES";
        };
      }
    ];
    ensureDatabases = [ "bors_ng" ];
    #initialScript = pkgs.writeText "initial.sql" ''
    #  CREATE USER "bors-ng" PASSWORD 'bors-ng' SUPERUSER;
    #  CREATE DATABASE bors_ng OWNER "bors-ng";
    #'';
    authentication = ''
      # allow access to bors_ng database from docker container
      # TYPE  DATABASE    USER        CIDR-ADDRESS          METHOD
      host    bors_ng     bors_ng     127.0.0.1/8           md5
      host    bors_ng     bors_ng     ::1/128               md5
    '';
  };

  services.nginx = {
    enable = true;
    #commonHttpConfig = ''
    #  log_format x-fwd '$remote_addr - $remote_user [$time_local] '
    #                   '"$request" $status $body_bytes_sent '
    #                   '"$http_referer" "$http_user_agent" "$http_x_forwarded_for"';
    #  access_log syslog:server=unix:/dev/log x-fwd;
    #'';
    #recommendedGzipSettings = true;
    #recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts = {
      "${hostname}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.bors-ng.port}";
        };
      };
    };
  };
  security.acme = lib.mkIf (config.deployment.targetEnv != "libvirtd") {
    email = "devops@iohk.io";
    acceptTerms = true; # https://letsencrypt.org/repository/
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  environment.systemPackages = with pkgs; [ goaccess ];
}
