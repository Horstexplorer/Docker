# Unifi-Network-Application
###### Stack running the Unifi network application server
Up-to-date setup details can be found [here](https://docs.linuxserver.io/images/docker-unifi-network-application/).

## Configuration
###### View the following files for available configuration properties.
Environment files:  
- [unifi-network-application.env](./unifi-network-application.env)  
- [unifi-db.env](./unifi-db.env)

## Port allocation
###### The following network ports are being used. This specifications can differ when using a network proxy.

- 8443
- 3478/udp
- 10001/udp
- 8080
- 1900/udp
- 8843
- 8880
- 6789
- 5514/udp

## Data Persistence
###### Data persistency is being provided by using the following volumes and mounts
`unifi` volume mount for the unifi-network-application  
`unifi-data` volume mount for the database
