let
  sources = import ./nix/sources.nix;
  pkgs = import sources.nixpkgs {};
in pkgs.lib.fix (self: {
  ci = (import ./nix-darwin/test.nix { role = "ci"; host = "build"; port = "123"; hostname = "hostname"; }).system;
  buildkite-agent = (import ./nix-darwin/test.nix { role = "buildkite-agent"; host = "build"; port = "123"; hostname = "hostname"; }).system;
  hydra-slave = (import ./nix-darwin/test.nix { role = "hydra-slave"; host = "build"; port = "123"; hostname = "hostname"; }).system;
  signing = (import ./nix-darwin/test.nix { role = "signing"; host = "build"; port = "123"; hostname = "hostname"; }).system;
  required = pkgs.releaseTools.aggregate {
    name = "required";
    constituents = with self; [
      ci
      hydra-slave
      buildkite-agent
      signing
    ];
  };
})
