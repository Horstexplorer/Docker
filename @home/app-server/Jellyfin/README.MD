# Jellyfin
###### Stack running Jellyfin
Up-to-date setup details can be found [here](https://docs.linuxserver.io/images/docker-jellyfin/).

## Configuration
###### View the following files for available configuration properties.
Environment files:  
- [jellyfin.env](./jellyfin.env)  

Requirements:
- Nvidia runtime requires a compatible gpu to be installed
- Service is proxied through [Caddy](../Caddy)

## Port allocation
###### The following network ports are being used. This specifications can differ when using a network proxy.

- 8096
- 8920
- 7359/udp
- 1900/udp

## Data Persistence
###### Data persistency is being provided by using the following volumes and mounts
`jellyfin` volume mount for jellyfin
`/mnt/media-share` bind mount for media contents
