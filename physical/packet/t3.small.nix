{ ... }: {
  imports = [ ./. ];
  deployment.packet.plan = "t3.small.x86";
  boot.loader.grub = {
    efiSupport = false;
    enable = true;
    version = 2;
    device = "/dev/sda";
  };
}
