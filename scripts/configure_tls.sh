#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
cd "$(dirname "$0")/.."
domain=${1:?Usage: sudo bash scripts/configure_tls.sh DOMAIN EMAIL}
email=${2:?Supply certificate contact email}
[[ $domain =~ ^[a-z0-9-]+\.duckdns\.org$ ]] || { echo 'Expected a DuckDNS hostname.' >&2; exit 1; }
if [[ ! -s /etc/letsencrypt/live/$domain/fullchain.pem ]]; then
  sed "s/__DOMAIN__/$domain/g" nginx/meridian-http.conf > /etc/nginx/sites-available/meridian
  ln -sfn /etc/nginx/sites-available/meridian /etc/nginx/sites-enabled/meridian
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
  certbot certonly --nginx --non-interactive --agree-tos --email "$email" -d "$domain"
fi
sed "s/__DOMAIN__/$domain/g" nginx/meridian-https-reference.conf > /etc/nginx/sites-available/meridian
ln -sfn /etc/nginx/sites-available/meridian /etc/nginx/sites-enabled/meridian
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
certbot renew --dry-run
