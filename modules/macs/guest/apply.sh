#!/usr/bin/env bash

echo "apply started at $(date)" /dev/udp/@host@/@port@

printf '\n*.*\t@@host@:@port@\n' >> /etc/syslog.conf

scutil --set HostName @hostname@
scutil --set LocalHostName @hostname@
scutil --set ComputerName @hostname@
dscacheutil -flushcache

exec 3>&1
exec 2> >(nc -u @host@ @port@)
exec 1>&2

pkill syslog
pkill asl
sudo systemsetup -setcomputersleep Never
echo "preventing sleep with caffeinate"
sudo caffeinate -s &

PS4='${BASH_SOURCE}::${FUNCNAME[0]}::$LINENO '
set -o pipefail
set -ex
date

function finish {
    set +e
    cd /
    sleep 1
    umount -f /Volumes/CONFIG
}
trap finish EXIT

cat <<EOF >> /etc/ssh/sshd_config
PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
EOF

launchctl stop com.openssh.sshd
launchctl unload /System/Library/LaunchDaemons/com.apple.platform.ptmd.plist
launchctl unload /System/Library/LaunchDaemons/com.apple.metadata.mds.plist

softwareupdate --schedule off

cd /Volumes/CONFIG

cp -rf ./etc/ssh/ssh_host_* /etc/ssh
chown root:wheel /etc/ssh/ssh_host_*
chmod 600 /etc/ssh/ssh_host_*
launchctl start com.openssh.sshd
cd /

echo "%admin ALL = NOPASSWD: ALL" > /etc/sudoers.d/passwordless

(
    # Make this thing work as root
    # shellcheck disable=SC2030,SC2031
    export USER=root
    # shellcheck disable=SC2030,SC2031
    export HOME=~root
    export ALLOW_PREEXISTING_INSTALLATION=1
    env
    curl https://nixos.org/releases/nix/nix-2.3.10/install > ~nixos/install-nix
    sudo -i -H -u nixos -- sh ~nixos/install-nix --daemon --darwin-use-unencrypted-nix-store-volume < /dev/null
)

(
    # Make this thing work as root
    # shellcheck disable=SC2030,SC2031
    export USER=root
    # shellcheck disable=SC2030,SC2031
    export HOME=~root

    mkdir -pv /etc/nix
cat <<EOF > /etc/nix/nix.conf
substituters = http://@host@:8081
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=
EOF

    # shellcheck disable=SC1091
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    env
    ls -la /private || true
    ls -la /private/var || true
    ls -la /private/var/run || true
    ln -s /private/var/run /run || true
    nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs
    nix-channel --add @nixDarwinUrl@ darwin
    nix-channel --update

    sudo -i -H -u nixos -- nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs
    sudo -i -H -u nixos -- nix-channel --add @nixDarwinUrl@ darwin
    sudo -i -H -u nixos -- nix-channel --update

    export NIX_PATH=$NIX_PATH:darwin=@nixDarwinUrl@

    installer=$(nix-build @nixDarwinUrl@ -A installer --no-out-link)
    set +e
    yes | sudo -i -H -u nixos -- "$installer/bin/darwin-installer"
    echo $?
    sudo launchctl kickstart system/org.nixos.nix-daemon
    set -e
    sleep 30
)
(
    if [ -d /Volumes/CONFIG/buildkite ]
    then
      cp -a /Volumes/CONFIG/buildkite /Users/nixos/buildkite
      pushd /Users/nixos/buildkite
      mv buildkite-ssh-iohk-devops-public-* buildkite-ssh-iohk-devops-public
      mv buildkite-ssh-iohk-devops-private-* buildkite-ssh-iohk-devops-private
      popd
    fi
)
(
    if [ -d /Volumes/CONFIG/hercules ]
    then
      mkdir -p /var/lib/hercules-ci-agent/
      cp -a /Volumes/CONFIG/hercules /var/lib/hercules-ci-agent/secrets
    fi
)
(
    # shellcheck disable=SC2031
    export USER=root
    # shellcheck disable=SC2031
    export HOME=~root

    rm -f /etc/bashrc
    ln -s /etc/static/bashrc /etc/bashrc
    # shellcheck disable=SC1091
    . /etc/static/bashrc
    cp -vf /Volumes/CONFIG/darwin-configuration.nix ~nixos/.nixpkgs/darwin-configuration.nix
    cp -vrf /Volumes/CONFIG/ci-ops ~nixos/.nixpkgs/ci-ops
    chown -R nixos ~nixos/.nixpkgs
    sudo -iHu nixos -- darwin-rebuild -I /nix/var/nix/profiles/per-user/nixos/channels -I darwin-config=/Users/nixos/.nixpkgs/darwin-configuration.nix build
    rm -f /etc/nix/nix.conf
    test -f /Volumes/CONFIG/nix/netrc && cp /Volumes/CONFIG/nix/netrc /etc/nix
    sudo -iHu nixos -- darwin-rebuild -I /nix/var/nix/profiles/per-user/nixos/channels -I darwin-config=/Users/nixos/.nixpkgs/darwin-configuration.nix switch
)
(
    if [ -f /Volumes/CONFIG/signing-config.json ]; then
        set +x
        echo Setting up signing...
        # shellcheck disable=SC1091
        source /Volumes/CONFIG/signing.sh
        # shellcheck disable=SC1091
        source /Volumes/CONFIG/signing-catalyst.sh
        security create-keychain -p "$KEYCHAIN" ci-signing.keychain
        security default-keychain -s ci-signing.keychain
        security set-keychain-settings ci-signing.keychain
        security list-keychains -d user -s login.keychain ci-signing.keychain
        security unlock-keychain -p "$KEYCHAIN"
        security show-keychain-info ci-signing.keychain
        security import /Volumes/CONFIG/iohk-sign.p12 -P "$SIGNING" -k "ci-signing.keychain" -T /usr/bin/productsign
        security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN" "ci-signing.keychain"
        security import /Volumes/CONFIG/iohk-codesign.cer -k /Library/Keychains/System.keychain
        security import /Volumes/CONFIG/AppleWWDRCAG3.cer -k /Library/Keychains/System.keychain
        security import /Volumes/CONFIG/iohk-codesign.p12 -P "$CODESIGNING" -k /Library/Keychains/System.keychain -T /usr/bin/codesign
        security import /Volumes/CONFIG/catalyst-ios-dev.p12 -P "$CATALYST" -k /Library/Keychains/System.keychain -T /usr/bin/codesign
        security import /Volumes/CONFIG/catalyst-ios-dist.p12 -P "$CATALYSTDIST" -k /Library/Keychains/System.keychain -T /usr/bin/codesign


        cp /private/var/root/Library/Keychains/ci-signing.keychain-db /Users/nixos/Library/Keychains/
        chown nixos:staff /Users/nixos/Library/Keychains/ci-signing.keychain-db
        mkdir -p /var/lib/buildkite-agent/.private_keys
        cp /private/var/root/Library/Keychains/ci-signing.keychain-db /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/signing.sh /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/signing-catalyst.sh /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/signing-config.json /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/code-signing-config.json /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/catalyst-ios-build.json /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/catalyst-env.sh /var/lib/buildkite-agent/
        cp /Volumes/CONFIG/catalyst-sentry.properties /var/lib/buildkite-agent/
        cp "/Volumes/CONFIG/AuthKey_${CATALYSTKEY}.p8" "/var/lib/buildkite-agent/.private_keys/AuthKey_${CATALYSTKEY}.p8"
        chown buildkite-agent:admin /var/lib/buildkite-agent/{ci-signing.keychain-db,signing.sh,signing-config.json,code-signing-config.json}
        chown -R buildkite-agent:admin /var/lib/buildkite-agent/{signing-catalyst.sh,catalyst-ios-build.json,catalyst-env.sh,.private_keys}
        chmod 0700 /var/lib/buildkite-agent/.private_keys
        chmod 0400 /var/lib/buildkite-agent/{signing.sh,signing-catalyst.sh} /var/lib/buildkite-agent/.private_keys/*

        export KEYCHAIN
        sudo -Eu nixos -- security unlock-keychain -p "$KEYCHAIN" /Users/nixos/Library/Keychains/ci-signing.keychain-db
        sudo -Eu buildkite-agent -- security unlock-keychain -p "$KEYCHAIN" /var/lib/buildkite-agent/ci-signing.keychain-db
        security unlock-keychain -p "$KEYCHAIN"

        mkdir -p "/var/lib/buildkite-agent/Library/MobileDevice/Provisioning Profiles/"
        mkdir -p /var/lib/buildkite-agent/Library/Developer
        UUID=$(strings /Volumes/CONFIG/catalyst-dev.mobileprovision | grep -A1 UUID | tail -n 1 | egrep -io "[-A-F0-9]{36}")
        cp /Volumes/CONFIG/catalyst-dev.mobileprovision "/var/lib/buildkite-agent/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
        UUID=$(strings /Volumes/CONFIG/catalyst-dist.mobileprovision | grep -A1 UUID | tail -n 1 | egrep -io "[-A-F0-9]{36}")
        cp /Volumes/CONFIG/catalyst-dist.mobileprovision "/var/lib/buildkite-agent/Library/MobileDevice/Provisioning Profiles/$UUID.mobileprovision"
        chown -R buildkite-agent:admin /var/lib/buildkite-agent/Library
        set -x
    fi
)
