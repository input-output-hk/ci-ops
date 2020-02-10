#!/usr/bin/env bash

set -euxo pipefail

# https://nixos.org/nixops/manual/#idm140737322394336
# Needed for libvirtd:
#
# virtualisation.libvirtd.enable = true;
# networking.firewall.checkReversePath = false;

if [ ! -d /var/lib/libvirt/images ]; then
  sudo mkdir -p /var/lib/libvirt/images
  sudo chgrp libvirtd /var/lib/libvirt/images
  sudo chmod g+w /var/lib/libvirt/images
fi

# If monitoring server is desired, see `create-aws.sh`
# for examples of setting up grafana and graylog creds

# NixOps setup

nixops destroy || true
nixops delete || true
nixops create ./deployments/$NIXOPS_DEPLOYMENT.nix
