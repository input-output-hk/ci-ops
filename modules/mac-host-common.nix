{ pkgs, lib, config, globals, ... }:

let
  cfg = config.macosGuest;
  inherit (config.services) ssh-keys;
in {
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    ./macs/host
    ./macs/host/macmini-boot-fixes.nix
    ./cachecache.nix
    ./ssh-keys.nix
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
      initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" "zfs" "nvme" ];
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
    networking.firewall.allowedTCPPorts = [
      5900 5901 # vnc
      5950 5951 # spice
      8081
    ];
    networking.firewall.extraCommands = lib.mkAfter ''
      iptables -t nat -A nixos-nat-pre -i wg0 -p tcp -m tcp --dport 2200 -j DNAT --to-destination 192.168.3.2:22
      iptables -t nat -A nixos-nat-pre -i wg0 -p tcp -m tcp --dport 2201 -j DNAT --to-destination 192.168.4.2:22

      # Match the 1-indexing in ci-world cluster for guests
      iptables -t nat -A nixos-nat-pre -i wg-zt -p tcp -m tcp --dport 2201 -m iprange --dst-range 10.10.0.1-10.10.0.50 -j DNAT --to-destination 192.168.3.2:22
      iptables -t nat -A nixos-nat-pre -i wg-zt -p tcp -m tcp --dport 2202 -m iprange --dst-range 10.10.0.1-10.10.0.50 -j DNAT --to-destination 192.168.4.2:22
    '';

    # Temporary wg replacement for zt
    networking.wireguard.interfaces.wg-zt = let
      wgIpOctet = lib.toInt (builtins.head (builtins.match ".*-([0-9]+)$" config.networking.hostName));
    in {
      listenPort = 51821;
      ips = ["10.10.0.${toString wgIpOctet}/32"];
      privateKeyFile = "/etc/wireguard/private.key";
      peers = [
        {
          publicKey = "ET2Hbi1sywNSCWhGYGqBham7ZhNdMYyuhUNRiOqILlQ=";
          allowedIPs = [
            "10.10.0.254/32"
            # The CIDRs below could be source NATd at the zt gateway, but since they are
            # currently non-collisional with existing mac CIDR ranges in use,
            # we'll use them unNATed for easier packet debug.
            "10.24.0.0/16"
            "10.32.0.0/16"
            "10.52.0.0/16"
            "172.16.0.0/16"
          ];
          endpoint = "zt.ci.iog.io:51820";
          persistentKeepalive = 30;
        }
      ];
    };
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
        (genPeer 3 "cardano-deployer" "${lib.strings.removeSuffix "\n" (builtins.readFile ../secrets/old-deployer-ip.txt)}:51820")
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
        { # Newer P42 Hydra
          publicKey = "yDQMpW8Qkc89LmcZSlIOIHodVpYp2QF6wIlq3EZGNlE=";
          allowedIPs = [ "192.168.142.3/32" ];
          endpoint = "hydra-wg.p42.at:17777";
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
      openssh.authorizedKeys.keys = ssh-keys.devOps;
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
          zvolName = "tank/monterey-image1-128gb";
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
            memoryInMegs = 24 * 1024;
            ovmfCodeFile = ./macs/dist/OVMF_CODE.fd;
            ovmfVarsFile = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
            MACAddress = "52:54:00:c9:18:27";
            vncListen = "0.0.0.0:0";
            spicePort = 5950;
          };
        };
        # Disable signing guest while Xcode image is legacy
        # signing = {
        #   zvolName = "tank/monterey-image2-xcode-128gb";
        #   network = {
        #     interiorNetworkPrefix = "192.168.4";
        #     guestSshPort = 2201;
        #     prometheusPort = 9102;
        #     tapDevice = "tap-signing";
        #     guestIP = "192.168.4.2";
        #   };
        #   guest = {
        #     guestConfigDir = guestConfDir2 "192.168.4.1" "1515" "${config.networking.hostName}-signing";
        #     cores = 2;
        #     threads = 2;
        #     sockets = 1;
        #     memoryInMegs = 12 * 1024;
        #     ovmfCodeFile = ./macs/dist/OVMF_CODE.fd;
        #     ovmfVarsFile = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
        #     MACAddress = "52:54:00:c9:18:28";
        #     vncListen = "0.0.0.0:1";
        #     spicePort = 5951;
        #   };
        # };
      };
    };
  };
}
