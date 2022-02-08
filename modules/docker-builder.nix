{ name, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "daily";
    autoPrune.flags = [ "--all" "--force" ];
  };

  # Work around for https://github.com/docker/cli/issues/2104
  systemd.enableUnifiedCgroupHierarchy = false;

  # Provide dockerhub credentials to buildkite
  systemd.services.buildkite-agent-iohk-setup-docker = {
    wantedBy = [ "buildkite-agent-iohk.service" ];
    script = ''
      mkdir -p ~buildkite-agent-iohk/.docker
      ln -sf /run/keys/dockerhub-auth ~buildkite-agent-iohk/.docker/config.json
      chown -R buildkite-agent-iohk:buildkite-agent-iohk ~buildkite-agent-iohk/.docker
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };
}
