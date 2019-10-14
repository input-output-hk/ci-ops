{ pkgs, ... }: {
  imports = [ ./. ];
  deployment.libvirtd.memorySize = 1024 * 4;
}
