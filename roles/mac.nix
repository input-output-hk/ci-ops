{ lib, name, config, ... }: {
  # Generic mac wireguard and buildkite key config
  deployment = {
    keys = {
      "private.key" = {
        destDir = "/etc/wireguard";
        keyFile = ../secrets/wireguard + "/${name}.private";
      };
      "buildkite_token_ci" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/buildkite";
        keyFile = ../secrets/buildkite_token;
      };
      "buildkite_token_signing" = {
        destDir = "/var/lib/macos-vm-persistent-config-signing/buildkite";
        keyFile = ../secrets/buildkite_token;
      };
      "buildkite_aws_creds_ci" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/buildkite";
        keyFile = ../secrets/buildkite-hook;
      };
      "buildkite_aws_creds_signing" = {
        destDir = "/var/lib/macos-vm-persistent-config-signing/buildkite";
        keyFile = ../secrets/buildkite-hook;
      };
      "buildkite-ssh-iohk-devops-private-ci" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/buildkite";
        keyFile = ../secrets/buildkite-iohk-devops-ssh;
      };
      "buildkite-ssh-iohk-devops-public-ci" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/buildkite";
        keyFile = ../secrets/buildkite-iohk-devops-ssh.pub;
      };
      "buildkite-ssh-iohk-devops-private-signing" = {
        destDir = "/var/lib/macos-vm-persistent-config-signing/buildkite";
        keyFile = ../secrets/buildkite-iohk-devops-ssh;
      };
      "buildkite-ssh-iohk-devops-public-signing" = {
        destDir = "/var/lib/macos-vm-persistent-config-signing/buildkite";
        keyFile = ../secrets/buildkite-iohk-devops-ssh.pub;
      };
      "cluster-join-token.key" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/hercules";
        keyFile = ../secrets/hercules-ci-token.key;
      };
      "binary-caches.json" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/hercules";
        keyFile = ../secrets/cachix-binary-caches.json;
      };
      "netrc" = {
        destDir = "/var/lib/macos-vm-persistent-config-ci/nix";
        text = ''
          machine github.com
            password ${lib.fileContents ../secrets/github_token}
        '';
      };
    };
  };
}
