#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg nginx certbot python3-certbot-nginx awscli cron unzip git logrotate
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
# shellcheck source=/dev/null
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker nginx cron certbot.timer
# Membership in docker grants root-equivalent access; only the deployment user is added.
usermod -aG docker ubuntu
install -d -m 0750 -o ubuntu -g ubuntu /opt/meridian
install -d -m 0700 -o ubuntu -g ubuntu /opt/meridian/backups
cat > /etc/cron.d/meridian-backup <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# 02:00 UTC daily (03:00 Lagos on the default Ubuntu UTC host).
0 2 * * * ubuntu cd /opt/meridian && /bin/bash scripts/backup_db.sh >> /opt/meridian/backups/cron.log 2>&1
EOF
chmod 0644 /etc/cron.d/meridian-backup
cat > /etc/logrotate.d/meridian-backup <<'EOF'
/opt/meridian/backups/cron.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    su ubuntu ubuntu
    create 0600 ubuntu ubuntu
}
EOF
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nnginx -t && systemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
chmod 0755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx
echo 'Bootstrap complete. Install .env, deploy services, configure DNS, then run configure_tls.sh.'
