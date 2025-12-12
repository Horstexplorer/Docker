# System: `electric-jaguar`

## Hardware Requirements
- **CPU:** `2 Cores`
- **RAM:** `2 GB`
- **Storage:** 
  - Primary OS `10 GB`
  - Secondary Data `50 GB`

## Additional Setup
### 1) Apply configuration to docker daemon
Update `/etc/docker/daemon.json` to include the following:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00:####:####:0001::/64",
  "ipv6tables": true
}
```
This enables required features as well as IPv6 support.
