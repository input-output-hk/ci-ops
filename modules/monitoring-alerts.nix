{ pkgs, lib, nodes, ... }: {
  services.monitoring-services.applicationRules = [
    {
      alert = "prometheus WAL corruption";
      expr = "(rate(prometheus_tsdb_wal_corruptions_total[5m]) OR on() vector(1)) > 0";
      for = "5m";
      labels.severity = "page";
      annotations = {
        description = "{{$labels.alias}} Prometheus WAL corruption total is changing or a no data condition has been detected";
      };
    }
  ];
}
