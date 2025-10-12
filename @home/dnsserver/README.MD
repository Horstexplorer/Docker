# System: `dnsserver`

## Hardware Requirements
- **CPU:** `4 Cores`
- **RAM:** `8 GB`
- **Storage:** 
  - Primary OS `32 GB`
  - Secondary Data `32 GB`

## Additional Setup
### 1) Apply configuration to docker daemon
Update `/etc/docker/daemon.json` to include the following:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:c0a8:0102:0001::/64"
}
```
This enables required features as well as IPv6 support.
