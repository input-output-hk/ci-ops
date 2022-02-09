{ ... }: {
  imports = [ ./. ];
  deployment.packet.plan = "c1.small.x86";
  boot.loader.grub = {
    efiSupport = false;
    enable = true;
    version = 2;
    device = "/dev/sda";
  };
}
