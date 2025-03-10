# SearXNG
###### Stack running SearXNG
Up-to-date setup details can be found [here](https://docs.searxng.org/admin/installation-docker.html).

## Configuration
###### View the following files for available configuration properties.
Environment files:  
- [searxng.env](./searxng.env)  

Requirements:
- Service is proxied through [Caddy](../Caddy)

## Port allocation
###### The following network ports are being used. This specifications can differ when using a network proxy.

- 8080

## Data Persistence
###### Data persistency is being provided by using the following volumes and mounts
`searxng` volume mount for searxng  
`searxng-valkey` volume mount for cache
