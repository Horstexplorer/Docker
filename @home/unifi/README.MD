# System: `unifi`

## Hardware Requirements
- **CPU:** `2 Cores`
- **RAM:** `2 GB`
- **Storage:** 
  - Primary OS `32 GB`

## Additional Setup

### 1) Install Unifi OS Server
- Refresh package list and install required packages: sudo apt-get update && sudo apt-get install podman slirp4netns curl
- Download the Installer from the [Ubiquiti website](https://ui.com/download/software/unifi-os-server).
  - `curl -O <uos_server_download_link> && chmod +x <local_path_to_uos_server_download>`
- Run the installer.