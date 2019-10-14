#!/usr/bin/env bash

dir=./static

rm -rf $dir

nix-shell ../jormungandr-nix/shell.nix \
  -A bootstrap \
  --arg customConfig "{ numberOfStakePools = 4; slots_per_epoch = 21600; slot_duration = 20; consensus_genesis_praos_active_slot_coeff = 0.2; kes_update_speed = 86400; rootDir = \"$dir\"; numberOfLeaders = 4; }" \
  --run 'echo done'
