{ config, ... }: let
  sources = import ../nix/sources.nix;
in {
  imports = [ (sources.hercules-ci-agent + "/module.nix") ];
  services.hercules-ci-agent.enable = true;
  services.hercules-ci-agent.concurrentTasks = 3;
  deployment.keys."cluster-join-token.key".keyFile = ../secrets/hercules-ci-token.key;
  deployment.keys."binary-caches.json".keyFile = ../secrets/cachix-binary-caches.json;
}
