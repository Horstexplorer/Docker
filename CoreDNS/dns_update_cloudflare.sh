#!/bin/bash

function update_dns_entry() {
  echo "Updating DNS Record $1 $2 $3 --> $4"
  curl -s --request PATCH \
    --url "https://api.cloudflare.com/client/v4/zones/$1/dns_records/$2" \
    --header "Content-Type: application/json" \
    --header "X-Auth-Email: $5" \
    --header "Authorization: Bearer $6" \
    --data '{
    "content": "'$4'",
    "name": "'$3'",
    "proxied": false,
    "ttl": 1
  }'
}

echo "Updating DNS A Records On Cloudflare"
ip=$(curl -s http://whatismyip.akamai.com/)
#ipv6=$(curl -s http://ipv6.whatismyip.akamai.com/)
echo "My IP is $ip"

#update_dns_entry "zone_id" "record_id" "record_name/@ for root" $ip "email" "bearer"



