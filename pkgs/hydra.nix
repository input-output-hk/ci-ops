let
  self = builtins.getFlake (toString ./..);
in
  self.inputs.hydra.outputs.packages.x86_64-linux.hydra
