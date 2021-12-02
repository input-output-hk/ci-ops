{ config, pkgs, ... }: {
  imports = [ ./. ];
  deployment.packet = {
    plan = "c3.medium.x86";
  };
}
