#!/usr/bin/env bash
set -Eeuo pipefail
subdomain=${1:?Usage: DUCKDNS_TOKEN=... bash scripts/update_duckdns.sh SUBDOMAIN PUBLIC_IP}
address=${2:?Supply Terraform ec2_public_ip output}
: "${DUCKDNS_TOKEN:?Supply DuckDNS token via environment}"
[[ $subdomain =~ ^[a-z0-9-]+$ && $address =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && $DUCKDNS_TOKEN =~ ^[a-zA-Z0-9-]+$ ]] || exit 1
# Read the token from stdin so it is absent from curl's process arguments.
response=$(printf 'url = "https://www.duckdns.org/update"\nget\ndata-urlencode = "domains=%s"\ndata-urlencode = "token=%s"\ndata-urlencode = "ip=%s"\n' "$subdomain" "$DUCKDNS_TOKEN" "$address" | curl --config - --fail --silent --show-error)
[[ $response == OK ]] || { echo 'DuckDNS update failed.' >&2; exit 1; }
echo "DuckDNS updated: $subdomain.duckdns.org -> $address"
