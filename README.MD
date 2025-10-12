# Docker 🐋
This repository provides reference configurations for all Docker-based deployments running on my servers.
Each deployment runs on a Debian-based environment and is managed using Docker Compose.
All Compose configurations are located within the `/docker` directory.

## Environments and services
The following environments and services are covered in this documentation:

### **@home**

- [AppServer](@home/appserver)
  - [Caddy](@home/appserver/Caddy)
  - [ComfyUi](@home/appserver/ComfyUi)
  - [Jellyfin](@home/appserver/Jellyfin)
  - [Jupyter](@home/appserver/Jupyter)
  - [Ollama](@home/appserver/Ollama)
  - [SearXNG](@home/appserver/SearXNG)
  - [Torrent](@home/appserver/Torrent)
  - [Vaultwarden](@home/appserver/Vaultwarden)
  - [Wireguard](@home/appserver/Wireguard)
  - [Wyoming](@home/appserver/Wyoming)
- [DNSServer](@home/dnsserver)
  - [Core DNS](@home/dnsserver/CoreDNS)
- [MailServer](@home/mailserver)
  - [Mailcow Dockerized](@home/mailserver/mailcow-dockerized)
- [Unifi](@home/unifi)
  - [Unifi Network Application](@home/unifi/Unify)

## Preparing a new environment
Starting from a fresh Debian installation, these steps will get Docker set up in a way that keeps behavior and file locations consistent across systems, which makes moving or copying setups much easier.

### 1) [Install Docker on Debian](https://docs.docker.com/engine/install/debian/)
### 2) Prepare persistency
To make future environment os upgrades easier, all Docker-related data should be stored on a secondary volume.
1. **Create and mount a partition**
    Mount the partition at `/mnt/data`.

     ```bash
     mkfs.ext4 /dev/sdX1 # ⚠️ Skip this step if data is already present on the disk
     mkdir -p /mnt/data
   
     # add to fstab
     # UUID=<partition-uuid>   /mnt/data     ext4 defaults,discard 0 0

     mount -a    
     ```  

2. **Copy existing Docker data**  
    ⚠️ Skip this step if data is already present on the partition.

    ```bash
    cp -rp /var/lib/docker /mnt/data/
    ```

3. **Create a bind mount to the original Docker location**  
    ```
    # add to fstab
    # /mnt/data/docker/   /var/lib/docker   none defaults,bind 0 0
    ```

4. **Setup Docker Compose configuration location**  
   ```bash
   mkdir /docker
   mkdir /mnt/data/docker/compose # ⚠️ Skip this step if data is already present on the disk
   
   # add to fstab
   # /mnt/data/docker/compose   /docker   none defaults,bind 0 0
   
   mount -a
   ```
   
5. **Restart docker or the environment to confirm everything is working**  
    ```bash
    systemctl restart docker
    ```

### 3) Apply Environment-Specific Configuration
Additional setup may be required depending on the environment’s hardware, such as updating the Docker daemon configuration, installing GPU drivers, preparing the NVIDIA Container Toolkit, or other device-specific software.

## Deploying a new Compose stack

- **Location:**  
  Store all Compose stack configurations in the `/docker` directory. Each stack should have its own subfolder named after the stack.

- **Data Persistence:**  
  Use **Docker volumes** instead of directory bind mounts to ensure reliable data persistence.

- **Environment Variables:**  
  Place configuration-related environment variables in an `.env` file named after the corresponding service.

- **Networks:**  
  Every stack must define an explicit **default network**.  
  Reference external networks as needed.

- **Documentation:**  
  Add a comment above each image declaration with relevant setup information (e.g., a documentation URL).