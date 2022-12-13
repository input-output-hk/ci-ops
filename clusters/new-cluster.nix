{
  equinix-buildkite-1 = {
    imports = [
      ../roles/buildkite-agent-containers.nix
    ];
    services.buildkite-containers = {
      hostIdSuffix = "1";
      queue = "default";
    };
  };
  equinix-buildkite-2 = {
    imports = [
      ../roles/buildkite-agent-containers.nix
    ];
    services.buildkite-containers = {
      hostIdSuffix = "2";
      queue = "default";
    };
  };
  equinix-buildkite-3 = {
    imports = [
      ../roles/buildkite-benchmark-agent-container.nix
    ];
    services.buildkite-containers = {
      hostIdSuffix = "3";
      queue = "benchmark";
      containerList = [{
        containerName = "benchmark"; 
        guestIp = "10.254.1.11";
        prio = "9";
        tags.queue = "benchmark";
        tags.system = "x86_64-linux";
      }];
    };
  };
}
