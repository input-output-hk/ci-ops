{ config, pkgs, ... }: {
  imports = [ ./. ];
  services.zfs.trim.enable = true;
  systemd.services.zfs-config = {
    path = with pkgs; [ zfs ];
    script = ''
      zfs set compression=lz4 zpool
    '';
    wantedBy = [ "multi-user.target" ];
  };
  boot.kernelParams = [
    "zfs.zfs_arc_max=${toString (1024*1024*1024*10)}"
  ];
  deployment.packet = {
    plan = "s3.xlarge.x86";
    customData = {
      cpr_storage = {
        disks = [
          {
            device = "/dev/disk/by-packet-category/boot0";
            wipeTable = true;
            partitions = [
              {
                label = "BIOS";
                number = 1;
                size = "512M";
              }
              {
                label = "SWAP";
                number = 2;
                size = "3993600";
              }
              {
                label = "ROOT";
                number = 3;
                size = 0;
              }
            ];
          }
        ];
        filesystems = [
          {
            mount = {
              device = "/dev/disk/by-packet-category/boot0-part1";
              format = "vfat";
              point =  "/boot";
              create = {
                options = [
                  "32"
                  "-n"
                  "BIOS"
                ];
              };
            };
          }
          {
            mount = {
              device = "/dev/disk/by-packet-category/boot0-part2";
              format = "swap";
              point = "none";
              create = {
                options = [
                  "-L"
                  "SWAP"
                ];
              };
            };
          }
        ];
      };
      cpr_zfs = {
        pools = {
          zpool = {
            pool_properties = { };
            vdevs = [
              {
                disk = [
                  "/dev/disk/by-packet-category/boot1"
                  "/dev/disk/by-packet-category/boot0-part3"
                ];
              }
            ];
          };
          zstore = {
            pool_properties = { };
            vdevs = [
              {
                raidz3 = [
                  "/dev/disk/by-packet-category/storage0"
                  "/dev/disk/by-packet-category/storage1"
                  "/dev/disk/by-packet-category/storage2"
                  "/dev/disk/by-packet-category/storage3"
                  "/dev/disk/by-packet-category/storage4"
                  "/dev/disk/by-packet-category/storage5"
                ];
              }
              {
                raidz3 = [
                  "/dev/disk/by-packet-category/storage6"
                  "/dev/disk/by-packet-category/storage7"
                  "/dev/disk/by-packet-category/storage8"
                  "/dev/disk/by-packet-category/storage9"
                  "/dev/disk/by-packet-category/storage10"
                  "/dev/disk/by-packet-category/storage11"
                ];
              }
            ];
          };
        };
        datasets = {
          "zpool/root" = {
            properties = {
              mountpoint = "legacy";
            };
          };
          "zstore/nix" = {
            properties = {
              mountpoint = "legacy";
            };
          };
          "zpool/home" = {
            properties = {
              mountpoint = "legacy";
            };
          };
          "zpool/var" = {
            properties = {
              mountpoint = "legacy";
            };
          };
        };
        mounts = [
          {
            dataset = "zpool/root";
            point = "/";
          }
          {
            dataset = "zstore/nix";
            point = "/nix";
          }
          {
            dataset = "zstore/var";
            point = "/var";
          }
          {
            dataset = "zstore/home";
            point = "/home";
          }
        ];
      };
    };
  };
}
