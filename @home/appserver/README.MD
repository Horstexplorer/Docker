# System: `appserver`

## Hardware Requirements
- **CPU:** `10 Cores`
- **RAM:** `32 GB`
- **Storage:** 
  - Primary OS `32 GB`
  - Secondary Data `256 GB`
  - Cache `/mnt/cache`
  - Media `/mnt/media-share`
- **GPU** `NVIDIA`

## Additional Setup
### 1) Install NVIDIA drivers and toolkit
- Install graphics driver as outlined [here](https://wiki.debian.org/NvidiaGraphicsDrivers)  
    ⚠️ Make sure to use `linux-headers-amd64` instead of the version specific one
- Install nvidia container toolkit as outlined [here](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)  

### 2) Apply configuration to docker daemon
Update `/etc/docker/daemon.json` to include the following:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:c0a8:0514:0001::/64",
  "ip6tables": true,
  "runtimes": {
    "nvidia": {
      "args": [],
      "path": "nvidia-container-runtime"
    }
  }
}
```
This enables required features as well as IPv6 support.

### 3) Configure DNS update script
Configure the [DNS update script](../../scripts/dns-updater/) and make sure it runs automatically via cron job

```bash
crontab -e

# add
# */5 * * * * /root/dns_update_cloudflare.sh > /dev/null 2>&1
```
