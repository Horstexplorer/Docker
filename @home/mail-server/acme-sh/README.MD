# ACME.SH
###### Not actually running in a container; Providing certificates to Mailcow
Up-to-date setup details can be found [here](https://github.com/acmesh-official/acme.sh/wiki).

## Configuration
Follow setup as outlined in the documentation
### Fill details into account.conf
`ACCOUNT_EMAIL` to cloudflare account  
`DNS_API` "dns_cf"  
`DEFAULT_ACME_SERVER` "https://acme-v02.api.letsencrypt.org/directory"  
`CF_Account_Id` to access cloudflare  
`CF_Token` to access cloudflare  
`AUTO_UPGRADE` "1"  

### Issue a certificate
```
acme.sh --issue --dns dns_cf --server letsencrypt -d 'domain.tld'
```

### Deploy a certificate to mailcow
```
export DEPLOY_MAILCOW_PATH="/docker/mailcow-dockerized"
export DEPLOY_MAILCOW_RELOAD="docker compose restart"
export DEPLOY_MAILCOW_RELOAD="docker compose restart postfix-mailcow dovecot-mailcow nginx-mailcow"
acme.sh --deploy -d domain.tld --deploy-hook mailcow
```