{ pkgs, lib, nodes, ... }: {
  services.monitoring-services.applicationRules = [
    {
      alert = "jormungandr_node_stats_outage";
      expr = "((jormungandr_lastBlockHeight > bool 0) == bool 0) == 1";
      for = "20m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Jormungandr node stats endpoint outage detected for more than 10 minutes";
        description = "{{$labels.alias}}: Jormungandr node stats endpoint outage detected for more than 10 minutes";
      };
    }
    {
      alert = "jormungandr_block_divergence";
      expr = "max(jormungandr_lastBlockHeight) - ignoring(alias,instance,job,role) group_right(instance) jormungandr_lastBlockHeight > 20";
      for = "30m";
      labels = {
        severity = "page";
      };
      annotations = {
        summary = "{{$labels.alias}}: Jormungandr block divergence detected for more than 5 minutes";
        description = "{{$labels.alias}}: Jormungandr block divergence detected for more than 5 minutes";
      };
    }
    {
      alert = "jormungandr_blockheight_unchanged";
      expr = "rate(jormungandr_lastBlockHeight[5m]) == 0";
      for = "30m";
      #for = "10m";
      labels.severity = "page";
      annotations = {
       summary = "{{$labels.alias}} Jormungandr blockheight unchanged for >=30mins";
        description = "{{$labels.alias}} Jormungandr blockheight unchanged for >=30mins.";
        #summary = "{{$labels.alias}} Jormungandr blockheight unchanged for >=10mins";
        #description = "{{$labels.alias}} Jormungandr blockheight unchanged for >=10mins.";
      };
    }
    {
      alert = "prometheus WAL corruption";
      expr = "(rate(prometheus_tsdb_wal_corruptions_total[5m]) OR on() vector(1)) > 0";
      for = "5m";
      labels.severity = "page";
      annotations = {
        description = "{{$labels.alias}} Prometheus WAL corruption total is changing or a no data condition has been detected";
      };
    }
  ] ++ (lib.optional (nodes ? faucet) (
    let threshold = nodes.faucet.config.services.jormungandr-faucet.lovelacesToGive * 50;
        ada = threshold / 1000000;
    in {
    alert = "jormungandr_faucetFunds_monitor";
    expr = ''(jormungandr_address_funds{alias=~"faucet.*"}) < ${toString threshold}'';
    for = "5m";
    labels.severity = "page";
    annotations = {
      description = "{{$labels.alias}} Jormungandr faucet wallet balance is low (< ${toString ada} ADA)";
    };
  }));
}
