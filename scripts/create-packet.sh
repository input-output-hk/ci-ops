#!/usr/bin/env bash

set -euxo pipefail

# Credential setup

if [ ! -f ./static/graylog-creds.nix ]; then
  nix-shell ./scripts/gen-graylog-creds.nix
fi

if [ ! -f ./static/grafana-creds.nix ]; then
  nix-shell ./scripts/gen-grafana-creds.nix
fi

# NixOps setup

nixops destroy || true
nixops delete || true
nixops create ./deployments/$NIXOPS_DEPLOYMENT.nix
