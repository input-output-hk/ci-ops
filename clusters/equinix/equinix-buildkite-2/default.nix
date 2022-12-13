{
  deployment.targetEnv = "none";
  deployment.targetHost = "145.40.96.11";
  networking.useDHCP = false;
  imports = [
    ./auth.nix
    ./system.nix
  ];
}
