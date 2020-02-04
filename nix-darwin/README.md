# Configuring MacOS CI Machines

This directory contains an install script and configuration for
running CI roles on a macOS system. There are currently four roles:

 * [Buildkite Agent][agents] role
 * [Hydra build slave][machines] role
 * CI role (combined buildkite agent and hydra slave role)
 * Signing role (Daedalus buildkite agent, with xcode signing)


There are *a few manual steps* required on the target mac. After that,
deployments and redeployments are done through SSH from a *deployment
host*.

[agents]: https://buildkite.com/organizations/input-output-hk/agents
[machines]: https://hydra.iohk.io/machines

## Requirements

## Target Mac

* The Mac needs SSH enabled.

## Deployment host

* Needs a clone of `ci-ops` somewhere.

* Set up entries for the macs in `~/.ssh/config` and make sure you
  have confirmed the host keys.

## Setting up `nix-darwin`

### On the target Mac

1. Install [nix](https://nixos.org/nix/)

       curl https://nixos.org/nix/install | sh
       source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

2. Run the prepare script. Specify on the command line which role the
   Mac will be:

       nix-build -I ci-ops=https://github.com/input-output-hk/ci-ops/archive/master.tar.gz '<ci-ops/nix-darwin>'
       ./result/bin/deploy [ buildkite | hydra | ci | signing ]

   This will prepare the system so that `nix-darwin` can be installed.

   It will ask for the admin password so that it can `sudo`.

   It will take a while to start because it needs to download GHC to
   run, but should complete without errors.

3. (Buildkite only) Set up the `/Users/admin/buildkite` directory with
   the necessary secrets as follows:

   a. The following variables are required in
      `/Users/admin/buildkite/buildkite_aws_creds` for artifact uploads
      to work:

      ```
      export BUILDKITE_S3_ACCESS_KEY_ID=AK...
      export BUILDKITE_S3_SECRET_ACCESS_KEY=...
      export BUILDKITE_S3_DEFAULT_REGION=...
      ```

   b. Put the agent token into `/Users/admin/buildkite/buildkite_token`.


### From the deployment host

1. `cd ci-ops/nix-darwin`
2. `./deploy.hs --role ./roles/ROLE.nix HOSTS...`

Replace *HOSTS* with the ssh host name of the target mac(s).

Replace *ROLE* with `buildkite-agent`, `hydra-slave`, `ci` or `signing` as necessary.

Re-run this command as necessary to update the configuration of the Mac.

## What just happened?

It built a `nix-darwin` system from the given configuration and
activated it on the target mac.

Check that all necessary services are running with
`sudo launchctl list | grep org.nixos`.

### Buildkite

The agent should appear on the [Buildkite agents][agents] page.

The service log file is`/var/lib/buildkite-agent/buildkite-agent.log`.

### Hydra

You should be able to register this mac in your local `nix.buildMachines` and check that it builds things. For example:

    nix-build -E '(import <nixpkgs> { system = "x86_64-darwin"; }).pkgs.hello.overrideAttrs (oldAttrs: { doCheck = false; })'

## Details

The top-level configurations are in the [`roles`](./roles/)
subdirectory.

This configuration imports various configuration fragments from the
[`modules`](./modules/) subdirectory.

The expression to build a `nix-darwin` configuration with pinned
versions is in [`lib/build.nix`](./lib/build.nix).

The `nix-darwin` version is specified in
[`lib/nix-darwin.json`](./lib/nix-darwin.json) and the `nixpkgs`
revision in pinned in [`lib/nixpkgs.json`](./lib/nixpkgs.json).

The `buildkite-agent` package is actually plucked from a revision on
the `nixos-unstable` branch because the version in 18.03 is too old.

## After deploying

### Buildkite agent: Installer Package Signing Key

So that packaging signing works, follow the instructions in the
[MacOS CI Hosts and Guests][1] on the Wiki.

[1]: https://github.com/input-output-hk/internal-documentation/wiki/MacOS-CI-Host-and-Guests

### Hydra slave: Build Machines Setup

1. Register the host with the Hydra master by adding it to
   `nix.buildMachines` in
   [`../modules/hydra-master.nix`](../modules/hydra-master.nix).

2. After change is merged, redeploy Hydra (see [Operational Manual](https://github.com/input-output-hk/internal-documentation/wiki/Operational-Manual#hydraiohkio-and-ci-mainnet-deployer)).

3. After the poll interval (something like 5 minutes), the build slave will appear on the [Hydra machines][machines] page.
