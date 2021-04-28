{ pkgs, lib, config, globals, ... }:

let
  cfg = config.macosGuest;
in {
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ./macs/host
    ./macs/host/macmini-boot-fixes.nix
    ./cachecache.nix
  ];
  options = {
    #macosGuest.role = lib.mkOption {
    #  type = lib.types.enum [ "buildkite-agent" "hydra-slave" ];
    #};
  };
  config = {
    deployment.keys = {
      wg_shared = {
        keyFile = ../secrets/wireguard/shared.private;
        destDir = "/etc/wireguard";
      };
    };
    boot = {
      initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" "zfsUnstable" "nvme" ];
      kernelModules = [ "kvm-intel" ];
      extraModulePackages = with config.boot.kernelPackages; lib.mkForce [ zfsUnstable wireguard ];
      loader = {
        efi.canTouchEfiVariables = false;
        grub = {
          enable = true;
          version = 2;
          efiInstallAsRemovable = true;
          efiSupport = true;
          device = "nodev";
        };
      };
    };
    nix.maxJobs = 4;
    nixpkgs = {
      config.allowUnfree = true;
    };
    networking.firewall.allowedTCPPorts = [ 5900 5901 8081 ];
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -t nat -A nixos-nat-pre -i wg0 -p tcp -m tcp --dport 2200 -j DNAT --to-destination 192.168.3.2:22
      iptables -t nat -A nixos-nat-pre -i wg0 -p tcp -m tcp --dport 2201 -j DNAT --to-destination 192.168.4.2:22
    '';
    networking.wireguard.interfaces.wg0 = let
      genPeer = n: name: endpoint: {
        publicKey = lib.strings.removeSuffix "\n" (builtins.readFile (../secrets/wireguard + "/${name}.public"));
        allowedIPs = [ "192.168.20.${toString n}/32" ];
        persistentKeepalive = 30;
        inherit endpoint;
      };
    in {
      listenPort = 51820;
      privateKeyFile = "/etc/wireguard/private.key";
      peers = [
        {
          publicKey = "kf/f+PWsMPVtV0vMvjG7A8ShgRfdwFAb99u+ixBboBE=";
          allowedIPs = [ "192.168.20.0/24" ];
          endpoint = "monitoring.aws.iohkdev.io:51820";
          persistentKeepalive = 30;
        }
        {
          publicKey = "oycbQ1DhtRh0hhD5gpyiKTUh0USkAwbjMer6/h/aHg8=";
          allowedIPs = [ "192.168.21.1/32" ];
          endpoint = "99.192.62.202:51820";
          persistentKeepalive = 30;
        }
        (genPeer 2 "hydra" "hydra.iohk.io:51820")
        (genPeer 3 "cardano-deployer" "${lib.strings.removeSuffix "\n" (builtins.readFile ../secrets/old-deployer-ip.txt)}:51820")
        {
          publicKey = "MRowDI1eC9B5Hx/zgPk5yyq2eWSq6kYFW5Sjm7w52AY=";
          allowedIPs = [ "192.168.24.1/32" ];
          persistentKeepalive = 30;
          endpoint = "96.248.117.80:51820";
        }
        {
          publicKey = "x/cUIzSdoeXonP5gSelaEfN8yYT8kJvi8E1w/myvkDg=";
          allowedIPs = [ "192.168.24.2/32" ];
          persistentKeepalive = 30;
          endpoint = "serval.nrdxp.dev:51820";
        }
        # TODO: Add preshared key; migrate all to port 17777
        { # New CI Deployer
          publicKey = "ZWLewe0yVJ45eW39quTiyvC/kaxy8xNcVpD9QVvxwkk=";
          allowedIPs = [ "10.90.1.1/32" ];
          persistentKeepalive = 25;
          endpoint = "${globals.deployerIp}:17777";
        }
        { # New CI Monitoring
          publicKey = "Xfbn71lJWmyj64OKHvjrd33l03I42qe+7v8FA/QM4hc=";
          allowedIPs = [ "10.90.0.1/32" ];
          persistentKeepalive = 25;
          endpoint = "monitoring.ci.iohkdev.io:17777";
          presharedKeyFile = "/etc/wireguard/wg_shared";
        }
        { # New CI Hydra
          publicKey = "kGVeMqf0nrEfTt1goLPRwoRc7Mt61jhoz2QkWXs07yk=";
          allowedIPs = [ "10.90.0.2/32" ];
          persistentKeepalive = 25;
          endpoint = "hydra.ci.iohkdev.io:17777";
        }
        { # P42 Hydra
          publicKey = "GMCYZoSFyLuyUJYgQJkVwvW5E2SJxFjRayyJ7SL4oXg=";
          allowedIPs = [ "192.168.150.3/32" ];
          endpoint = "hydra.project42.iohkdev.io:51820";
          persistentKeepalive = 25;
        }
        { # Newer P42 Hydra
          publicKey = "yDQMpW8Qkc89LmcZSlIOIHodVpYp2QF6wIlq3EZGNlE=";
          allowedIPs = [ "192.168.142.3/32" ];
          endpoint = "hydra-wg.p42.at:17777";
          persistentKeepalive = 25;
        }
        { # Mantis Hydra
          publicKey = "O+Ec7HFu9QuROi88yL178KvzedlFkOEjDjuzLBy++HM=";
          allowedIPs = [ "192.168.18.2/32" ];
          endpoint = "hydra.mantis.ist:51820";
          persistentKeepalive = 25;
        }
      ];
    };
    monitorama = {
      enable = true;
      hosts = {
        "/monitorama/host" = "http://127.0.0.1:9100/metrics";
        "/monitorama/ci" = "http://192.168.3.2:9100/metrics";
        "/monitorama/signing" = "http://192.168.4.2:9100/metrics";
      };
    };
    environment.systemPackages = with pkgs; [
      wget vim screen
    ];
    users.users.root = {
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbtjKqNiaSVMBBSK4m97LXCBwhHMfJh9NBGBxDg+XYCLOHuuKw2MsHa4eMtRhnItELxhCAXZg0rdwZTlxLb6tzsVPXAVMrVniqfbG2qZpDPNElGdjkT0J5N1X1mOzmKymucJ1uHRDxTpalpg5d5wyGZgwVuXerep3nnv2xIIYcHWm5Hy/eG0pRw6XuQUeMc3xSU5ChqZPwWqhdILkYteKMgD8vxkfmYE9N/2fPgKRmujKQ5SA0HoJYKBXo29zGQY5r6nt3CzuIANFD3vG3323Znvt8dSRd1DiaZqKEDWSI43aZ9PX2whYEDyj+L/FvQa78Wn7pc8Nv2JOb7ur9io9t michael.bishop"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDEPOLnk4+mWNGOXd309PPxal8wgMzKXHnn7Jbu/SpSUYEc1EmjgnrVBcR0eDxgDmGD9zJ69wEH/zLQLPWjaTusiuF+bqAM/x7z7wwy1nZ48SYJw3Q+Xsgzeb0nvmNsPzb0mfnpI6av8MTHNt+xOqDnpC5B82h/voQ4m5DGMQz60ok2hMeh+sy4VIvX5zOVTOFPQqFR6BGDwtALiP5PwMfyScYXlebWHhDRdX9B0j9t+cqiy5utBUsl4cIUInE0KW7Z8Kf6gIsmQnfSZadqI857kdozU3IbaLoJc1C6LyVjzPFyC4+KUC11BmemTGdCjwcoqEZ0k5XtJaKFXacYYXi1l5MS7VdfHldFDZmMEMvfJG/PwvXN4prfOIjpy1521MJHGBNXRktvWhlNBgI1NUQlx7rGmPZmtrYdeclVnnY9Y4HIpkhm0iEt/XUZTMQpXhedd1BozpMp0h135an4uorIEUQnotkaGDwZIV3mSL8x4n6V02Qe2CYvqf4DcCSBv7D91N3JplJJKt7vV4ltwrseDPxDtCxXrQfSIQd0VGmwu1D9FzzDOuk/MGCiCMFCKIKngxZLzajjgfc9+rGLZ94iDz90jfk6GF4hgF78oFNfPEwoGl0soyZM7960QdBcHgB5QF9+9Yd6QhCb/6+ENM9sz6VLdAY7f/9hj/3Aq0Lm4Q== samuel.leathers@iohk.io"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCogRPMTKyOIQcbS/DqbYijPrreltBHf5ctqFOVAlehvpj8enEE51VSjj4Xs/JEsPWpOJL7Ldp6lDNgFzyuL2AOUWE7wlHx2HrfeCOVkPEzC3uL4OjRTCdsNoleM3Ny2/Qxb0eX2SPoSsEGvpwvTMfUapEa1Ak7Gf39voTYOucoM/lIB/P7MKYkEYiaYaZBcTwjxZa3E+v7At4umSZzv8x24NV60fAyyYmt5hVZRYgoMW+nTU4J/Oq9JGgY7o+WPsOWcgFoSretRnGDwjM1IAUFVpI45rQH2HTKNJ6Bp6ncKwtVaP2dvPdBFe3x2LLEhmh1jDwmbtSXfoVZxbONtub2i/D8DuDhLUNBx/ROgal7N2RgYPcPuNdzfp8hMPjPGZVcSmszC/J1Gz5LqLfWbKKKti4NiSX+euy+aYlgW8zQlUS7aGxzRC/JSgk2KJynFEKJjhj7L9KzsE8ysIgggxYdk18ozDxz2FMPMV5PD1+8x4anWyfda6WR8CXfHlshTwhe+BkgSbsYNe6wZRDGqL2no/PY+GTYRNLgzN721Nv99htIccJoOxeTcs329CppqRNFeDeJkGOnJGc41ze+eVNUkYxOP0O+pNwT7zNDKwRwBnT44F0nNwRByzj2z8i6/deNPmu2sd9IZie8KCygqFiqZ8LjlWTD6JAXPKtTo5GHNQ== john.lotoski@iohk.io"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDB5LMY783Srcv4pCfCjcjgug+Xq1EGTLP1AJWugGgXg tim.deherrera@iohk.io"
      ];
    };
    swapDevices = [
      {
        label = "swap";
      }
    ];
    services = {
      pcscd.enable = true;
      cachecache.enable = true; # port 8081
      openssh = {
        enable = true;
        permitRootLogin = "yes";
      };
    };
    powerManagement.cpuFreqGovernor = "performance";
    fileSystems = {
      "/" = {
        fsType = "zfs";
        device = "tank/root";
      };
      "/home" = {
        fsType = "zfs";
        device = "tank/home";
      };
      "/nix" = {
        fsType = "zfs";
        device = "tank/nix";
      };
      "/boot" = {
        # WARNING, this will find the guest /boot within zfs, not the host /boot on nvme
        # label = "EFI";
        device = "/dev/nvme0n1p1";
        fsType = "vfat";
      };
    };
    macosGuest = let
      guestConfDir1 = host: port: hostname: (import ../nix-darwin/test.nix { role = "ci"; inherit host port hostname; }).guestConfDir;
      guestConfDir2 = host: port: hostname: (import ../nix-darwin/test.nix { role = "signing"; inherit host port hostname; }).guestConfDir;
    in {
      enable = true;
      network = {
        externalInterface = "ens1";
        tapDevices = {
          tap-ci = {
            subnet = "192.168.3";
          };
          tap-signing = {
            subnet = "192.168.4";
          };
        };
      };
      machines = {
        ci = {
          zvolName = "tank/mojave-image1-128gb";
          network = {
            interiorNetworkPrefix = "192.168.3";
            guestSshPort = 2200;
            prometheusPort = 9101;
            tapDevice = "tap-ci";
            guestIP = "192.168.3.2";
          };
          guest = {
            guestConfigDir = guestConfDir1 "192.168.3.1" "1514" "${config.networking.hostName}-ci";
            cores = 2;
            threads = 2;
            sockets = 1;
            memoryInMegs = 12 * 1024;
            ovmfCodeFile = ./macs/dist/OVMF_CODE.fd;
            ovmfVarsFile = ./macs/dist/OVMF_VARS-1024x768.fd;
            cloverImage = (pkgs.callPackage ./macs/clover-image.nix { csrFlag = "0x23"; }).clover-image;
            MACAddress = "52:54:00:c9:18:27";
            vncListen = "0.0.0.0:0";
          };
        };
        signing = {
          zvolName = "tank/mojave-image2-xcode-128gb";
          network = {
            interiorNetworkPrefix = "192.168.4";
            guestSshPort = 2201;
            prometheusPort = 9102;
            tapDevice = "tap-signing";
            guestIP = "192.168.4.2";
          };
          guest = {
            guestConfigDir = guestConfDir2 "192.168.4.1" "1515" "${config.networking.hostName}-signing";
            cores = 2;
            threads = 2;
            sockets = 1;
            memoryInMegs = 6 * 1024;
            ovmfCodeFile = ./macs/dist/OVMF_CODE.fd;
            ovmfVarsFile = ./macs/dist/OVMF_VARS-1024x768.fd;
            cloverImage = (pkgs.callPackage ./macs/clover-image.nix { csrFlag = "0x23"; }).clover-image;
            MACAddress = "52:54:00:c9:18:28";
            vncListen = "0.0.0.0:1";
          };
        };
      };
    };
  };
}
