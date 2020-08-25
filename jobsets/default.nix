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
, cardanoByronProxyPrsJSON ? ./simple-pr-dummy.json
, cardanoDbSyncPrsJSON ? ./simple-pr-dummy.json
, cardanoExplorerAppPrsJSON ? ./simple-pr-dummy.json
, cardanoFaucetPrsJSON ? ./simple-pr-dummy.json
, cardanoGraphQLPrsJSON ? ./simple-pr-dummy.json
, cardanoLedgerSpecsPrsJSON ? ./simple-pr-dummy.json
, cardanoNodePrsJSON ? ./simple-pr-dummy.json
, cardanoPreludePrsJSON ? ./simple-pr-dummy.json
, cardanoPrsJSON ? ./simple-pr-dummy.json
, cardanoRestPrsJSON ? ./simple-pr-dummy.json
, cardanoRosettaPrsJSON ? ./simple-pr-dummy.json
, ciOpsPrsJSON ? ./simple-pr-dummy.json
, daedalusPrsJSON ? ./simple-pr-dummy.json
, decentralizedSoftwareUpdatesPrsJSON ? ./simple-pr-dummy.json
, explorerPrsJSON ? ./simple-pr-dummy.json
, haskellNixPrsJSON ? ./simple-pr-dummy.json
, iohkMonitoringPrsJSON ? ./simple-pr-dummy.json
, iohkNixPrsJSON ? ./simple-pr-dummy.json
, jormungandrPrsJSON ? ./simple-pr-dummy.json
, kesPrsJSON ? ./simple-pr-dummy.json
, ledgerPrsJSON ? ./simple-pr-dummy.json
, logClassifierPrsJSON ? ./simple-pr-dummy.json
, nixopsPrsJSON ? ./simple-pr-dummy.json
, ouroborosNetworkPrsJSON ? ./simple-pr-dummy.json
, plutusPrsJSON ? ./simple-pr-dummy.json
, shellPrsJSON ? ./simple-pr-dummy.json
, smashPrsJSON ? ./simple-pr-dummy.json
, toolsPrsJSON ? ./simple-pr-dummy.json
, walletPrsJSON ? ./simple-pr-dummy.json
, rustLibsPrsJSON ? ./simple-pr-dummy.json
}:

let pkgs = import nixpkgs {}; in

with pkgs.lib;

let

  ##########################################################################
  # GitHub repos to make jobsets for.
  # These are processed by the mkRepoJobsets function below.

  repos = {
    cardano-sl = {
      description = "Cardano SL";
      url = "https://github.com/input-output-hk/cardano-sl.git";
      input = "cardano";  # corresponds to argument in cardano-sl/release.nix
      branch = "develop";
      branches = {
        master = "master";
        "1-0" = "release/1.0.x";
        "1-2" = "release/1.2.0";
        "1-3" = "release/1.3.1";
        "2-0" = "release/2.0.0";
        "3-0-1" = "release/3.0.1";
      };
      prs = cardanoPrsJSON;
      prJobsetModifier = withFasterBuild;
      bors = true;
    };

    jormungandr = {
      description = "jormungandr";
      url = "https://github.com/input-output-hk/jormungandr-nix.git";
      input = "jormungandr";
      branch = "master";
      prs = jormungandrPrsJSON;
      bors = true;
    };

    daedalus = {
      description = "Daedalus Wallet";
      url = "https://github.com/input-output-hk/daedalus.git";
      branch = "develop";
      prs = daedalusPrsJSON;
      bors = true;
    };

    plutus = {
      description = "Plutus Language";
      url = "https://github.com/input-output-hk/plutus.git";
      prs = plutusPrsJSON;
    };

    log-classifier = {
      description = "Log Classifier";
      url = "https://github.com/input-output-hk/log-classifier.git";
      prs = logClassifierPrsJSON;
      bors = true;
    };

    cardano-addresses = {
      description = "Cardano Addresses";
      url = "https://github.com/input-output-hk/cardano-addresses.git";
      branch = "master";
      prs = cardanoAddressesPrsJSON;
      bors = true;
    };

    cardano-ledger = {
      description = "Cardano Ledger";
      url = "https://github.com/input-output-hk/cardano-ledger.git";
      branch = "master";
      prs = ledgerPrsJSON;
      bors = true;
    };

    cardano-ledger-specs = {
      description = "Cardano Ledger Specs";
      url = "https://github.com/input-output-hk/cardano-ledger-specs.git";
      branch = "master";
      prs = cardanoLedgerSpecsPrsJSON;
      bors = true;
    };

    ouroboros-network = {
      description = "Ouroboros Network";
      url = "https://github.com/input-output-hk/ouroboros-network.git";
      branch = "master";
      prs = ouroborosNetworkPrsJSON;
      bors = true;
    };

    cardano-byron-proxy = {
      description = "Cardano Byron Proxy";
      url = "https://github.com/input-output-hk/cardano-byron-proxy.git";
      branch = "master";
      prs = cardanoByronProxyPrsJSON;
      bors = true;
    };

    cardano-prelude = {
      description = "Cardano Byron Proxy";
      url = "https://github.com/input-output-hk/cardano-prelude.git";
      branch = "master";
      prs = cardanoPreludePrsJSON;
      bors = true;
    };

    cardano-rosetta = {
      description = "Cardano Rosetta API";
      url = "https://github.com/input-output-hk/cardano-rosetta.git";
      branch = "master";
      prs = cardanoRosettaPrsJSON;
      bors = true;
    };

    decentralized-software-updates = {
      description = "Decentralized Software Updates";
      url = "https://github.com/input-output-hk/decentralized-software-updates";
      branch = "master";
      prs = decentralizedSoftwareUpdatesPrsJSON;
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

    ci-ops = {
      description = "IOHK CI Infrastructure Repo";
      url = "https://github.com/input-output-hk/ci-ops.git";
      branch = "master";
      prs = ciOpsPrsJSON;
      bors = true;
    };

    haskell-nix = {
      description = "Haskell.nix Build System";
      url = "https://github.com/input-output-hk/haskell.nix.git";
      branch = "master";
      prs = haskellNixPrsJSON;
      bors = true;
      genericModifier = { schedulingshares = 10; };
    };

    cardano-wallet = {
      description = "Cardano Wallet Backend";
      url = "https://github.com/input-output-hk/cardano-wallet.git";
      branch = "master";
      prs = walletPrsJSON;
      bors = true;
    };

    rust-libs = {
      description = "Rust Libs";
      url = "https://github.com/input-output-hk/rust-libs.nix.git";
      branch = "master";
      prs = rustLibsPrsJSON;
      bors = true;
    };

    cardano-shell = {
      description = "Cardano Shell";
      url = "https://github.com/input-output-hk/cardano-shell.git";
      branch = "master";
      prs = shellPrsJSON;
      bors = true;
    };

    cardano-node = {
      description = "Cardano Node";
      url = "https://github.com/input-output-hk/cardano-node.git";
      prs = cardanoNodePrsJSON;
      bors = true;
    };

    cardano-benchmarking = {
      description = "Cardano benchmarks";
      url = "https://github.com/input-output-hk/cardano-benchmarking.git";
      prs = cardanoBenchmarkingPrsJSON;
      bors = true;
    };

    cardano-base = {
      description = "Cardano Base";
      url = "https://github.com/input-output-hk/cardano-base.git";
      prs = cardanoBasePrsJSON;
      bors = true;
    };

    cardano-rest = {
      description = "Cardano REST API";
      url = "https://github.com/input-output-hk/cardano-rest.git";
      prs = cardanoRestPrsJSON;
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

    cardano-graphql = {
      description = "Cardano GraphQL";
      url = "https://github.com/input-output-hk/cardano-graphql.git";
      branch = "master";
      prs = cardanoGraphQLPrsJSON;
      bors = true;
    };

    cardano-faucet = {
      description = "Cardano Faucet";
      url = "https://github.com/input-output-hk/cardano-faucet.git";
      prs = cardanoFaucetPrsJSON;
      bors = true;
    };

    kes-mmm-sumed25519 = {
      description = "key evolving signature";
      url = "https://github.com/input-output-hk/kes-mmm-sumed25519.git";
      prs = kesPrsJSON;
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
  };

  ##########################################################################
  # Jobset generation functions

  mkFetchGithub = value: {
    inherit value;
    type = "git";
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

  # Merges the given attrset of Hydra inputs with a jobset.
  addInputs = inputs: jobset: jobset // {
    inputs = (jobset.inputs or { }) // inputs;
  };

  # Adds an arg which disables optimization for cardano-sl builds
  withFasterBuild = addInputs {
    fasterBuild = { type = "boolean"; emailresponsible = false; value = "true"; };
  };

  # Use to put Bors jobs at the front of the build queue.
  highPrio = jobset: jobset // {
    schedulingshares = 420;
  };

  keepNone = jobset: jobset // {
    keepnr = 0;
  };

  # Removes PRs which have any of the labels in ./pr-excluded-labels.nix
  exclusionFilter = let
    excludedLabels = import ./pr-excluded-labels.nix;
    justExcluded = filter (label: (elem label.name excludedLabels));
    isEmpty = ls: length ls == 0;
  in
    filterAttrs (_: prInfo: isEmpty (justExcluded (prInfo.labels or [])));

  loadPrsJSON = path: exclusionFilter (builtins.fromJSON (builtins.readFile path));

  # Make jobset for a project default build
  mkJobset = { name, description, url, input, branch, genericModifier }: let
    jobset = defaultSettings // {
      nixexprpath = "release.nix";
      nixexprinput = input;
      inherit description;
      inputs = {
        "${input}" = mkFetchGithub "${url} ${branch}";
      };
    } // genericModifier;
  in
    nameValuePair name jobset;

  # Make jobsets for extra project branches (e.g. release branches)
  mkJobsetBranches = { name, description, url, input, genericModifier }:
    mapAttrsToList (suffix: branch:
      mkJobset { name = "${name}-${suffix}"; inherit description url input branch genericModifier; });

  # Make a jobset for a GitHub PRs
  mkJobsetPR = { name, input, modifier, genericModifier }: num: info: {
    name = "${name}-pr-${num}";
    value = defaultSettings // modifier {
      description = "PR ${num}: ${info.title}";
      nixexprinput = input;
      nixexprpath = "release.nix";
      inputs = {
        "${input}" = mkFetchGithub "${info.base.repo.clone_url} pull/${num}/head";
        pr = { type = "string"; value = num; emailresponsible = false; };
      };
    } // genericModifier;
  };

  # Load the PRs json and make a jobset for each
  mkJobsetPRs = { name, input, modifier, prs, genericModifier }:
    mapAttrsToList
      (mkJobsetPR { inherit name input modifier genericModifier; })
      (loadPrsJSON prs);

  # Add two extra jobsets for the bors staging and trying branches.
  mkJobsetBors = { name, genericModifier, ... }@args: let
    jobset = branch: let
      js = (mkJobset (args // { branch = "bors/" + branch; })).value;
      extraInputs = { borsBuild = { type = "string"; value = branch; emailresponsible = false; }; };
    in addInputs extraInputs js;
  in [
    (nameValuePair "${name}-bors-staging" ((highPrio (jobset "staging")) // genericModifier))
    (nameValuePair "${name}-bors-trying" ((keepNone (jobset "trying")) // genericModifier))
  ];

  # Make all the jobsets for a project repo, according to the "repos" spec above.
  mkRepoJobsets = let
    mkRepo = name: info: let
      input = info.input or name;
      branch = info.branch or "master";
      params = { inherit name input; inherit (info) description url; };
      prJobsetModifier = info.prJobsetModifier or (s: s);
      genericModifier = info.genericModifier or {};
    in
      [ (mkJobset (params // { inherit branch genericModifier; })) ] ++
      (mkJobsetBranches (params // { inherit genericModifier; }) (info.branches or {})) ++
      (mkJobsetPRs { inherit name input genericModifier; inherit (info) prs; modifier = prJobsetModifier; }) ++
      (optionals (info.bors or false) (mkJobsetBors (params // { inherit genericModifier; })));
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
  nixopsPrJobsets = listToAttrs (mapAttrsToList makeNixopsPR (loadPrsJSON nixopsPrsJSON));

  ##########################################################################
  # Jobsets which don't fit into the regular structure

  extraJobsets = mapAttrs (name: settings: defaultSettings // settings) ({
    # Provides cached build projects for PR builds with -O0
    no-opt-cardano-sl = withFasterBuild mainJobsets.cardano-sl;

    # iohk-ops (this repo)
    iohk-ops = mkNixops "master" defaultNixpkgsRev;
    iohk-ops-bors-staging = highPrio (mkNixops "bors-staging" defaultNixpkgsRev);
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
