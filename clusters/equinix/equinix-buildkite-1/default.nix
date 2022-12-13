{
  deployment.targetEnv = "none";
  deployment.targetHost = "147.75.84.81";
  networking.useDHCP = false;
  imports = [
    ./auth.nix
    ./system.nix
  ];
}
