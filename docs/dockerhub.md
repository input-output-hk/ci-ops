# Generate config.json

1. Run `docker login`
2. Login with docker hub credentials for user with access to push
3. `cp ~/.docker/config.json secrets/dockerhub-auth-config.json`
4. deploy to all buildkite agents
