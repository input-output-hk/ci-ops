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
    {
      alert = "hydra_filesystem_full_75percent";
      expr = ''
        sort(node_filesystem_free_bytes{alias=~".*hydra.*", device!="ramfs"} < node_filesystem_size_bytes{alias=~".*hydra.*", device!="ramfs"} * 0.25) / 1024^3'';
      for = "5m";
      labels = { severity = "page"; };
      annotations = {
        summary =
          "{{$labels.alias}}: Hydra filesystem is running out of space soon.";
        description =
          "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} got less than 25% space left on its filesystem.";
      };
    }
    {
      alert = "hydra_inodes_full_75percent";
      expr = ''
        sort(node_filesystem_files_free{alias=~".*hydra.*", device!="ramfs"} < node_filesystem_files{alias=~".*hydra.*",device!="ramfs"} * 0.25)'';
      for = "5m";
      labels = { severity = "page"; };
      annotations = {
        summary =
          "{{$labels.alias}}: Hydra inodes are running out.";
        description =
          "{{$labels.alias}} device {{$labels.device}} on {{$labels.mountpoint}} got less than 25% inodes remaining on its filesystem.";
      };
    }
    {
      alert = "hydra_build_queue_unchanged_1h";
      expr = ''
        (rate((hydra_builds_queued > 0)[5m:10s]) == bool 0) == 1'';
      for = "1h";
      labels = { severity = "page"; };
      annotations = {
        summary =
          "{{$labels.alias}}: Hydra build queue isn't changing.";
        description =
          "{{$labels.alias}} Hydra build queue hasn't changed for 1 hour or more.";
      };
    }
    {
      alert = "hydra_build_queue_not_found";
      expr = ''
        ((hydra_builds_queued or on() vector(-1)) == bool -1) == 1'';
      for = "10m";
      labels = { severity = "page"; };
      annotations = {
        summary =
          "{{$labels.alias}}: Hydra build queue is missing.";
        description =
          "{{$labels.alias}} Hydra build queue has been missing for 10 minutes or more.";
      };
    }
  ];
}
