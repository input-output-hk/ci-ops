{ name, config, ... }:
{
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
    };
  };
}
