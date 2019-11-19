{ config, ... }:

{
  networking.firewall.allowedUDPPorts = [ 51820 ];
  networking.wireguard.interfaces.wg0 = {
    ips = [ "192.168.20.2/32" ];
    listenPort = 51820;
    privateKeyFile = "/etc/wireguard/hydra.wgprivate";
    peers = [
      { # sarov
        publicKey = "mC3XblolhrDxerxXCvF1vyXdAY208/1bJhhtsulk5DU=";
        allowedIPs = [ "192.168.20.20/32" ];
        persistentKeepalive = 30;
      }
      { # mac-mini-1
        publicKey = "nvKCarVUXdO0WtoDsEjTzU+bX0bwWYHJAM2Y3XhO0Ao=";
        allowedIPs = [ "192.168.20.21/32" ];
        persistentKeepalive = 30;
      }
      { # mac-mini-2
        publicKey = "VcOEVp/0EG4luwL2bMmvGvlDNDbCzk7Vkazd3RRl51w=";
        allowedIPs = [ "192.168.20.22/32" ];
        persistentKeepalive = 30;
      }
      {
        publicKey = "asG7R996ieVEhoeBHTK2DVNI664dfeBalL5dPqHIcXo=";
        allowedIPs = [ "192.168.20.0/24" ];
        endpoint = "monitoring.aws.iohkdev.io:51820";
        persistentKeepalive = 30;
      }
    ];
  };
}
