############################################################################
# This is the jobset declaration evaluated by Hydra to dynamically
# generate jobsets.
#
# The arguments for this file come from spec.json.
# So also update that file when you add a repo here.
#
# You may also want to check and update the GitHub notifications list
# in modules/hydra-master-main.nix.
#
# Test this file locally with:
#   jq . < $(nix-build --no-out-link jobsets/default.nix)
#
# See also the Hydra manual:
#   https://github.com/NixOS/hydra/blob/master/doc/manual/declarative-projects.xml
#
############################################################################

{ nixpkgs ? <nixpkgs>
, declInput ? {}

# Paths to JSON files containing PR info fetched from github.
# An example file is ./simple-pr-dummy.json.
, cardanoAddressesPrsJSON ? ./simple-pr-dummy.json
, cardanoBasePrsJSON ? ./simple-pr-dummy.json
, cardanoBenchmarkingPrsJSON ? ./simple-pr-dummy.json
, cardanoDbSyncPrsJSON ? ./simple-pr-dummy.json
, cardanoExplorerAppPrsJSON ? ./simple-pr-dummy.json
, cardanoFaucetPrsJSON ? ./simple-pr-dummy.json
, cardanoGraphQLPrsJSON ? ./simple-pr-dummy.json
, cardanoLedgerSpecsPrsJSON ? ./simple-pr-dummy.json
, cardanoNodeP2PPrsJSON ? ./simple-pr-dummy.json
, cardanoNodePrsJSON ? ./simple-pr-dummy.json
, cardanoOpsPrsJSON ? ./simple-pr-dummy.json
, cardanoPreludePrsJSON ? ./simple-pr-dummy.json
, cardanoRestPrsJSON ? ./simple-pr-dummy.json
, cardanoRosettaPrsJSON ? ./simple-pr-dummy.json
, cardanoRTViewPrsJSON ? ./simple-pr-dummy.json
, ciOpsPrsJSON ? ./simple-pr-dummy.json
, daedalusPrsJSON ? ./simple-pr-dummy.json
, decentralizedSoftwareUpdatesPrsJSON ? ./simple-pr-dummy.json
, explorerPrsJSON ? ./simple-pr-dummy.json
, haskellNixPrsJSON ? ./simple-pr-dummy.json
, hydraPocPrsJSON ? ./simple-pr-dummy.json
, iohkMonitoringPrsJSON ? ./simple-pr-dummy.json
, iohkNixPrsJSON ? ./simple-pr-dummy.json
, kesPrsJSON ? ./simple-pr-dummy.json
, ledgerPrsJSON ? ./simple-pr-dummy.json
, offchainMetadataToolsPrsJSON ? ./simple-pr-dummy.json
, nixopsPrsJSON ? ./simple-pr-dummy.json
, ouroborosNetworkPrsJSON ? ./simple-pr-dummy.json
, plutusPrsJSON ? ./simple-pr-dummy.json
, plutusStarterPrsJSON ? ./simple-pr-dummy.json
, shellPrsJSON ? ./simple-pr-dummy.json
, smashPrsJSON ? ./simple-pr-dummy.json
, toolsPrsJSON ? ./simple-pr-dummy.json
, votingToolsPrsJSON ? ./simple-pr-dummy.json
, walletPrsJSON ? ./simple-pr-dummy.json
}:

let pkgs = import nixpkgs {}; in

with pkgs.lib;

let

  ##########################################################################
  # GitHub repos to make jobsets for.
  # These are processed by the mkRepoJobsets function below.

  repos = {
    cardano-addresses = {
      description = "Cardano Addresses";
      url = "https://github.com/input-output-hk/cardano-addresses.git";
      branch = "master";
      prs = cardanoAddressesPrsJSON;
      bors = false;
    };

    cardano-base = {
      description = "Cardano Base";
      url = "https://github.com/input-output-hk/cardano-base.git";
      prs = cardanoBasePrsJSON;
      bors = true;
    };

    cardano-benchmarking = {
      description = "Cardano benchmarks";
      url = "https://github.com/input-output-hk/cardano-benchmarking.git";
      prs = cardanoBenchmarkingPrsJSON;
      bors = true;
    };

    cardano-db-sync = {
      description = "Cardano DB Sync";
      url = "https://github.com/input-output-hk/cardano-db-sync.git";
      prs = cardanoDbSyncPrsJSON;
      bors = true;
    };

    cardano-explorer-app = {
      description = "Cardano Explorer App";
      url = "https://github.com/input-output-hk/cardano-explorer-app.git";
      branch = "develop";
      prs = cardanoExplorerAppPrsJSON;
      bors = true;
    };

    cardano-faucet = {
      description = "Cardano Faucet";
      url = "https://github.com/input-output-hk/cardano-faucet.git";
      prs = cardanoFaucetPrsJSON;
      bors = true;
    };

    cardano-graphql = {
      description = "Cardano GraphQL";
      url = "https://github.com/input-output-hk/cardano-graphql.git";
      branch = "master";
      prs = cardanoGraphQLPrsJSON;
    };

    cardano-ledger-specs = {
      description = "Cardano Ledger Specs";
      url = "https://github.com/input-output-hk/cardano-ledger-specs.git";
      branch = "master";
      prs = cardanoLedgerSpecsPrsJSON;
      bors = true;
    };

    cardano-ledger = {
      description = "Cardano Ledger";
      url = "https://github.com/input-output-hk/cardano-ledger.git";
      branch = "master";
      prs = ledgerPrsJSON;
      bors = true;
    };

    cardano-node = {
      description = "Cardano Node";
      url = "https://github.com/input-output-hk/cardano-node.git";
      prs = cardanoNodePrsJSON;
      bors = true;
    };

    cardano-node-p2p = {
      description = "Cardano Node Peer to Peer";
      url = "https://github.com/input-output-hk/cardano-node.git";
      branch = "p2p-master";
      prs = cardanoNodeP2PPrsJSON;
      prFilter = dontBuildPrsFilter;
      bors = false;
    };

    cardano-ops = {
      description = "NixOps deployment configuration for IOHK/Cardano devops";
      url = "https://github.com/input-output-hk/cardano-ops.git";
      branch = "master";
      prs = cardanoOpsPrsJSON;
      bors = true;
    };

    cardano-prelude = {
      description = "Cardano Prelude";
      url = "https://github.com/input-output-hk/cardano-prelude.git";
      branch = "master";
      prs = cardanoPreludePrsJSON;
      bors = true;
    };

    cardano-rest = {
      description = "Cardano REST API";
      url = "https://github.com/input-output-hk/cardano-rest.git";
      prs = cardanoRestPrsJSON;
      bors = true;
    };

    cardano-rosetta = {
      description = "Cardano Rosetta API";
      url = "https://github.com/input-output-hk/cardano-rosetta.git";
      branch = "master";
      prs = cardanoRosettaPrsJSON;
    };

    cardano-rt-view = {
      description = "RTView";
      url = "https://github.com/input-output-hk/cardano-rt-view.git";
      branch = "master";
      prs = cardanoRTViewPrsJSON;
      bors = true;
    };

    cardano-shell = {
      description = "Cardano Shell";
      url = "https://github.com/input-output-hk/cardano-shell.git";
      branch = "master";
      prs = shellPrsJSON;
      bors = false;
    };

    cardano-wallet = {
      description = "Cardano Wallet Backend";
      url = "https://github.com/input-output-hk/cardano-wallet.git";
      branch = "master";
      prs = walletPrsJSON;
      bors = true;
    };

    ci-ops = {
      description = "IOHK CI Infrastructure Repo";
      url = "https://github.com/input-output-hk/ci-ops.git";
      branch = "master";
      prs = ciOpsPrsJSON;
      bors = true;
    };

    daedalus = {
      description = "Daedalus Wallet";
      url = "https://github.com/input-output-hk/daedalus.git";
      branch = "develop";
      prs = daedalusPrsJSON;
      bors = true;
    };

    decentralized-software-updates = {
      description = "Decentralized Software Updates";
      url = "https://github.com/input-output-hk/decentralized-software-updates";
      branch = "master";
      prs = decentralizedSoftwareUpdatesPrsJSON;
      bors = true;
    };

    haskell-nix = {
      description = "Haskell.nix Build System";
      url = "https://github.com/input-output-hk/haskell.nix.git";
      branch = "master";
      bors = true;
      prs = haskellNixPrsJSON;
      prFilter = inclusionFilter;
      modifier.schedulingshares = 10;
    };

    hydra-poc = {
      description = "Proof of concept for the Hydra Head protocol";
      url = "https://github.com/input-output-hk/hydra-poc.git";
      branch = "master";
      prs = hydraPocPrsJSON;
      bors = true;
    };

    iohk-monitoring = {
      description = "IOHK Monitoring Framework";
      url = "https://github.com/input-output-hk/iohk-monitoring-framework.git";
      branch = "master";
      prs = iohkMonitoringPrsJSON;
      bors = true;
    };

    iohk-nix = {
      description = "IOHK Common Nix Expressions";
      url = "https://github.com/input-output-hk/iohk-nix.git";
      branch = "master";
      prs = iohkNixPrsJSON;
      bors = true;
    };

    kes-mmm-sumed25519 = {
      description = "key evolving signature";
      url = "https://github.com/input-output-hk/kes-mmm-sumed25519.git";
      prs = kesPrsJSON;
      bors = true;
    };

    offchain-metadata-tools = {
      description = "Tools for creating, submitting, and managing off-chain metadata such as multi-asset token metadata";
      url = "https://github.com/input-output-hk/offchain-metadata-tools.git";
      branch = "master";
      prs = offchainMetadataToolsPrsJSON;
      bors = true;
    };

    ouroboros-network = {
      description = "Ouroboros Network";
      url = "https://github.com/input-output-hk/ouroboros-network.git";
      branch = "master";
      prs = ouroborosNetworkPrsJSON;
      bors = true;
    };

    plutus = {
      description = "Plutus Language";
      url = "https://github.com/input-output-hk/plutus.git";
      prs = plutusPrsJSON;
      branches = [ "marlowe-dist-demo" ];
    };

    plutus-starter = {
      description = "A starter project for Plutus apps";
      url = "https://github.com/input-output-hk/plutus-starter.git";
      branch = "main";
      prs = plutusStarterPrsJSON;
      bors = true;
    };

    smash = {
      description = "Stakepool Metadata Aggregation Server";
      url = "https://github.com/input-output-hk/smash.git";
      branch = "master";
      prs = smashPrsJSON;
      bors = true;
    };

    tools = {
      description = "Loony Tools";
      url = "https://github.com/input-output-hk/tools.git";
      branch = "master";
      prs = toolsPrsJSON;
    };

    voting-tools = {
      description = "Voting Tools";
      url = "https://github.com/input-output-hk/voting-tools.git";
      branch = "master";
      prs = votingToolsPrsJSON;
      bors = true;
    };
  };

  ##########################################################################
  # Jobset generation functions

  mkFetchGithub = value: {
    inherit value;
    type = "git";
    emailresponsible = false;
  };

  mkStringInput = value: {
    inherit value;
    type = "string";
    emailresponsible = false;
  };

  defaultSettings = {
    enabled = 1;
    hidden = false;
    nixexprinput = "jobsets";
    keepnr = 5;
    schedulingshares = 42;
    checkinterval = 60;
    inputs = {
      nixpkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${defaultNixpkgsRev}";
      jobsets = mkFetchGithub "${iohkOpsURI} master";
    };
    enableemail = false;
    emailoverride = "";
  };

  # Use this modifier to put Bors jobs at the front of the build
  # queue.
  highPrioJobset = {
    schedulingshares = 420;
  };

  # Modifier to disable keeping of build products for Bors "try" jobs.
  keepNoneJobset = {
    keepnr = 0;
  };

  prHasLabel = labelList: prInfo:
    length (filter (label: (elem label.name labelList)) (prInfo.labels or [])) != 0;
  prNotDraft = prInfo: !(prInfo.draft or false);

  # Removes PRs which have any of the excluded labels in ./pr-labels.nix
  exclusionFilter = prInfo: !(prHasLabel (import ./pr-labels.nix).excluded prInfo);
  # Removes PRs which don't have any of the included labels in ./pr-labels.nix
  inclusionFilter = prHasLabel (import ./pr-labels.nix).included;

  # Build only the repo branch target and not any additional PRs
  dontBuildPrsFilter = prInfo: false;

  loadPrsJSON = prFilter: path: filterAttrs (_: prFilter)
    (builtins.fromJSON (builtins.readFile path));

  # Make jobset for a project default build
  mkJobset = { name, description, url, input, branch, modifier ? {} }: let
    jobset = recursiveUpdate (defaultSettings // {
      nixexprpath = "release.nix";
      nixexprinput = input;
      inherit description;
      inputs = {
        "${input}" = mkFetchGithub "${url} ${branch}";
      };
    }) modifier;
  in
    nameValuePair name jobset;

  # Make jobsets for extra project branches (e.g. release branches)
  mkJobsetBranches = { name, description, url, input, modifier ? {} }:
    mapAttrsToList (suffix: branch:
      mkJobset { name = "${name}-${suffix}"; inherit description url input branch modifier; });

  # Make a jobset for a GitHub PRs
  mkJobsetPR = { name, input, modifier ? {} }: num: info: {
    name = "${name}-pr-${num}";
    value = recursiveUpdate (defaultSettings // {
      description = "PR ${num}: ${info.title}";
      nixexprinput = input;
      nixexprpath = "release.nix";
      inputs = {
        "${input}" = mkFetchGithub "${info.base.repo.clone_url} pull/${num}/head";
        pr = mkStringInput num;
      };
    }) modifier;
  };

  # Load the PRs json and make a jobset for each
  mkJobsetPRs = { name, input, prs, prFilter, modifier ? {} }:
    mapAttrsToList
      (mkJobsetPR { inherit name input modifier; })
      (loadPrsJSON prFilter prs);

  # Add two extra jobsets for the bors staging and trying branches.
  mkJobsetBors = { name, modifier, ... }@args: let
    jobset = branch: mod: (mkJobset (args // {
      branch = "bors/" + branch;
      modifier = recursiveUpdate (recursiveUpdate mod modifier) {
        inputs.borsBuild = mkStringInput branch;
      };
    })).value;
  in [
    (nameValuePair "${name}-bors-staging" (jobset "staging" highPrioJobset))
    (nameValuePair "${name}-bors-trying" (jobset "trying" keepNoneJobset))
  ];

  # Make all the jobsets for a project repo, according to the "repos" spec above.
  mkRepoJobsets = let
    mkRepo = name: info: let
      input = info.input or name;
      branch = info.branch or "master";
      modifier = info.modifier or {};
      params = { inherit name input modifier; inherit (info) description url; };
    in concatLists
      [ (optional (branch != null)
          (mkJobset (params // { inherit branch; })))
        (mkJobsetBranches params (info.branches or {}))
        (optionals (info ? prs)
          (mkJobsetPRs {
            inherit name input;
            inherit (info) prs;
            prFilter = info.prFilter or exclusionFilter;
            modifier = recursiveUpdate modifier (info.prModifier or {});
          }))
        (optionals (info.bors or false)
          (mkJobsetBors params))
      ];
  in
    rs: listToAttrs (concatLists (mapAttrsToList mkRepo rs));


  ##########################################################################
  # iohk-ops structure is slightly different

  iohkOpsURI = "https://github.com/input-output-hk/iohk-ops.git";
  defaultNixpkgsRev = "541d9cce8af7a490fb9085305939569567cb58e6";
  mkNixops = nixopsBranch: nixpkgsRev: {
    nixexprpath = "jobsets/cardano.nix";
    description = "IOHK-Ops";
    inputs = {
      nixpkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${nixpkgsRev}";
      jobsets = mkFetchGithub "${iohkOpsURI} ${nixopsBranch}";
      nixops = mkFetchGithub "https://github.com/NixOS/NixOps.git tags/v1.5";
    };
  };
  makeNixopsPR = num: info: {
    name = "iohk-ops-pr-${num}";
    value = defaultSettings // {
      description = "PR ${num}: ${info.title}";
      nixexprpath = "jobsets/cardano.nix";
      inputs = {
        nixpkgs = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${defaultNixpkgsRev}";
        jobsets = mkFetchGithub "${info.base.repo.clone_url} pull/${num}/head";
        nixops = mkFetchGithub "https://github.com/NixOS/NixOps.git tags/v1.5";
      };
    };
  };
  nixopsPrJobsets = listToAttrs (mapAttrsToList makeNixopsPR (loadPrsJSON exclusionFilter nixopsPrsJSON));

  ##########################################################################
  # Jobsets which don't fit into the regular structure

  extraJobsets = mapAttrs (name: settings: defaultSettings // settings) ({
    # ci-ops (this repo)
    iohk-ops = mkNixops "master" defaultNixpkgsRev;
    iohk-ops-bors-staging = recursiveUpdate (mkNixops "bors-staging" defaultNixpkgsRev) highPrioJobset;
    iohk-ops-bors-trying = mkNixops "bors-trying" defaultNixpkgsRev;
  } // nixopsPrJobsets);

  ##########################################################################
  # The final jobsets spec as JSON

  mainJobsets = mkRepoJobsets repos;
  jobsetsAttrs = mainJobsets // extraJobsets;
in {
  jobsets = pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toJSON declInput}
    EOF
    cp ${pkgs.writeText "spec.json" (builtins.toJSON jobsetsAttrs)} $out
  '';
}
