{ python3, makeWrapper, runCommand, scrapeTarget, bindingAddress, bindingPort }:

let
  python = python3.withPackages (ps: with ps; [ requests systemd prometheus_client ]);
in runCommand "hydra-monitor" {
  inherit scrapeTarget bindingAddress bindingPort;
  buildInputs = [ python makeWrapper ];
} ''
  substituteAll ${./hydra-monitor.py} $out
  chmod +x $out
  patchShebangs $out
''
