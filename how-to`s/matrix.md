# Matrix
Using Synapse

## Generate home server configuration
```bash
docker run -it --rm \
  --mount type=volume,src=matrix-synapse,dst=/data \
  -e SYNAPSE_SERVER_NAME=<domain.tld> \
  -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
```

## Generate Matrix Auth configuration
```bash
docker run --rm \
  ghcr.io/element-hq/matrix-authentication-service config generate > config.yaml
```