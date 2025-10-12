# CoreDNS
###### Stack running an intermediate dns server
Up-to-date setup details can be found [here](https://hub.docker.com/r/coredns/coredns/).

## Configuration
###### View the following files for available configuration properties.
Environment files:
- [coredns.conf](./coredns.conf)
- [hosts.conf](./hosts.conf)

## Port allocation
###### The following network ports are being used. This specifications can differ when using a network proxy.

- 53
- 53/udp

## Data Persistence
###### Data persistency is being provided by using the following volumes and mounts
`coredns.conf` bind mount for the coredns configuration file  
`hosts.conf` bind mount for configuring hostname resolutions  
