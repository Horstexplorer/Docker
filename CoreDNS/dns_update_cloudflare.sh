#!/bin/bash

function update_dns_entry() {
  echo "Updating DNS Record $3 $4 $5 --> $6 (proxied=$7, ttl=$8)"
  curl -s --request PATCH \
    --url "https://api.cloudflare.com/client/v4/zones/$3/dns_records/$4" \
    --header "Content-Type: application/json" \
    --header "X-Auth-Email: $1" \
    --header "Authorization: Bearer $2" \
    --data '{
    "content": "'$6'",
    "name": "'$5'",
    "proxied": '$7',
    "ttl": '$8'
  }' > /dev/null
}

echo "Updating DNS Records On Cloudflare"
ip=$(curl -s http://whatismyip.akamai.com/)
ipv6=$(curl -s http://ipv6.whatismyip.akamai.com/)
echo "My IP is $ip / $ipv6"

# update_dns_entry "email@domain.tld" "auth key" "zone_id" "record_id" "name" $ip "proxied" "ttl"