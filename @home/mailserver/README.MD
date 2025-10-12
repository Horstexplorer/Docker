# System: `mailserver`

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
  "fixed-cidr-v6":"fd00:dead:beef:c0::/80",
  "experimental":true,
  "ip6tables":true
}
```
This enables required features as well as IPv6 support.

### 2) Configure DNS update script
Configure the [DNS update script](../../scripts/dns-updater/) and make sure it runs automatically via cron job

```bash
crontab -e

# add
# */5 * * * * /root/dns_update_cloudflare.sh > /dev/null 2>&1
```

### 3) Configure certificate update
- Install [acme.sh](https://github.com/acmesh-official/acme.sh)
- Fill in account details to account.conf
    `ACCOUNT_EMAIL` to cloudflare account  
    `DNS_API` "dns_cf"  
    `DEFAULT_ACME_SERVER` "https://acme-v02.api.letsencrypt.org/directory"  
    `CF_Account_Id` to access cloudflare  
    `CF_Token` to access cloudflare  
    `AUTO_UPGRADE` "1"
- Issue a certificate
    ```bash
    acme.sh --issue --dns dns_cf --server letsencrypt -d 'domain.tld'
    ```
- Deploy a certificate to mailcow (after setup)
    ```bash
      export DEPLOY_MAILCOW_PATH="/docker/mailcow-dockerized"
      export DEPLOY_MAILCOW_RELOAD="docker compose restart"
      export DEPLOY_MAILCOW_RELOAD="docker compose restart postfix-mailcow dovecot-mailcow nginx-mailcow"
      acme.sh --deploy -d domain.tld --deploy-hook mailcow
    ```