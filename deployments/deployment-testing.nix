{
  hydra = { resources, ... }: {
    deployment.targetEnv = "ec2";
    deployment.ec2.region = "eu-west-2";
    deployment.ec2.instanceType = "m5.4xlarge";
    deployment.ec2.keyPair = resources.ec2KeyPairs.todo;
  };
  resources.ec2KeyPairs.todo = {
    region = "eu-test-2";
  };
}
