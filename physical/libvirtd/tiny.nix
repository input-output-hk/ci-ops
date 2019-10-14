{ pkgs, ... }: {
  imports = [ ./. ];
  deployment.libvirtd.memorySize = 512;
}
