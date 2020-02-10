{ ... }:
let
  sharedKey = "wg_shared";
in {
  imports = [ ./wireguard.nix ];
  networking.wg-quick.interfaces.wg0 = {
    peers = [
      { # mac-mini-1
        allowedIPs = [ "192.168.20.21/32" ];
        publicKey = "nvKCarVUXdO0WtoDsEjTzU+bX0bwWYHJAM2Y3XhO0Ao=";
        #presharedKeyFile = "/run/keys/${sharedKey}";
        persistentKeepalive = 25;
      }
      { # mac-mini-2
        allowedIPs = [ "192.168.20.22/32" ];
        publicKey = "VcOEVp/0EG4luwL2bMmvGvlDNDbCzk7Vkazd3RRl51w=";
        #presharedKeyFile = "/run/keys/${sharedKey}";
        persistentKeepalive = 25;
      }
    ];
  };
}
