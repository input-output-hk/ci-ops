
{ config, lib, pkgs, ... }:
let
  inherit (config.macosGuest.guest) threads cores sockets memoryInMegs
    snapshotName;
  inherit (lib) mkIf;

in {
  config = mkIf config.macosGuest.enable {

    systemd.services = builtins.listToAttrs (builtins.concatLists (lib.mapAttrsFlatten (key: value: let
      inherit (value) zvolName;
      snapshot = "${zvolName}@${snapshotName}";
      clonedVol = "${zvolName}-${key}";
      clonedZvolDevice = "/dev/zvol/${clonedVol}";
      inherit (value.guest) cores threads sockets memoryInMegs MACAddress;
      deps = [ "create-macos-secrets-${key}.service" "dhcpd4.service" "kresd@.service" "network-online.target" ];
    in [ {
      name = "run-macos-vm-${key}";
      value = {
        requires = deps;
        after = deps;
        wantedBy = [ "multi-user.target" ];
        wants = [ "netcatsyslog.service" ];
        path = with pkgs; [ zfs qemu cdrkit rsync findutils ];

        serviceConfig.PrivateTmp = true;

        preStart = ''
          echo prestart script
          zfs destroy ${clonedVol} || true
          while [ -e /dev/${clonedVol} ]
          do
            echo "waiting for volume to finish removing"
            sleep 5
          done
          zfs clone ${snapshot} ${clonedVol}

          # Create a cloud-init style cdrom
          rm -rf /tmp/cdr
          cp -r ${value.guest.persistentConfigDir} /tmp/cdr
          rsync -a ${value.guest.guestConfigDir}/ /tmp/cdr
          cd /tmp/cdr
          chmod +x apply.sh
          find .
          genisoimage -v -J -r -V CONFIG -o /tmp/config.iso .
        '';
        postStop = ''
          echo poststop script
          rm -rf /tmp/OSX-KVM

          while [ -e /dev/${clonedVol} ]
          do
            zfs destroy ${clonedVol} || (echo "waiting for volume to finish removing" ; sleep 1)
          done
        '';

        script = let
          osxKVM = pkgs.fetchFromGitHub {
            owner = "kholia";
            repo = "OSX-KVM";
            rev = "670cd80d7b011447453152feeae5ccf637250f8f";
            sha256 = "14f49yvv53jj2vkvcbfqnzcww8fq0hc40r9sxs49m20ghdylyh91";
          };
        in ''
          cp -r ${osxKVM} /tmp/OSX-KVM
          chmod 644 -R /tmp/OSX-KVM

          MY_OPTIONS="+ssse3,+sse4.2,+popcnt,+avx,+aes,+avx2,+smep,+xsave,+xsaveopt,check"

          REPO_PATH="/tmp/OSX-KVM"
          OVMF_DIR="."

          # shellcheck disable=SC2054
          args=(
            -enable-kvm -cpu Penryn,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,"$MY_OPTIONS"
            -machine q35
            -smp cpus=${toString (cores * threads * sockets)},cores=${toString cores},threads=${toString threads},sockets=${toString sockets} \
            -m ${toString memoryInMegs} \
            -usb -device usb-kbd -device usb-tablet
            -device usb-ehci,id=ehci
            -device nec-usb-xhci,id=xhci
            -global nec-usb-xhci.msi=off
            -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"
            -drive if=pflash,format=raw,readonly=on,file="$REPO_PATH/$OVMF_DIR/OVMF_CODE.fd"
            -drive if=pflash,format=raw,file="$REPO_PATH/$OVMF_DIR/OVMF_VARS-1024x768.fd"
            -smbios type=2
            -device ich9-intel-hda -device hda-duplex
            -device ich9-ahci,id=sata
            -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file="$REPO_PATH/OpenCore/OpenCore.qcow2"
            -device ide-hd,bus=sata.2,drive=OpenCoreBoot
            -drive id=MacHDD,cache=unsafe,if=none,file=${clonedZvolDevice},format=raw
            -device ide-hd,bus=sata.4,drive=MacHDD
            -device ide-cd,bus=sata.3,drive=config
            -drive id=config,if=none,snapshot=on,media=cdrom,file=/tmp/config.iso
            -netdev tap,id=net0,ifname=tap-${key},script=no,downscript=no -device e1000-82545em,netdev=net0,id=net0,mac=${MACAddress} \
            -vnc ${value.guest.vncListen} \
            -spice port=${toString value.guest.spicePort},addr=0.0.0.0,image-compression=auto_glz,playback-compression=off,agent-mouse=on,zlib-glz-wan-compression=never,jpeg-wan-compression=never,seamless-migration=on,disable-ticketing=on,plaintext-channel=main,plaintext-channel=display,plaintext-channel=inputs,plaintext-channel=cursor,plaintext-channel=playback,plaintext-channel=record,plaintext-channel=usbredir,streaming-video=filter \
            -monitor unix:/tmp/monitor-socket,server,nowait
          )

          qemu-system-x86_64 "''${args[@]}"
        '';
      };
    }
    {
      name = "create-macos-secrets-${key}";
      value = {
        path = with pkgs; [ openssh ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          if [ ! -f ${value.guest.persistentConfigDir}/etc/ssh/ssh_host_ed25519_key ]; then
            mkdir -p ${value.guest.persistentConfigDir}/etc/ssh
            ssh-keygen -A -f ${value.guest.persistentConfigDir}
          fi
        '';
      };
    } ]) config.macosGuest.machines));
  };
}
