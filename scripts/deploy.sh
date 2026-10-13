#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
region=${1:?AWS region required}
registry=${2:?ECR registry required}
prefix=${3:?Repository prefix required}
tag=${4:?Immutable image tag required}
[[ $region =~ ^[a-z]{2}-[a-z]+-[0-9]+$ && $registry =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com$ && $prefix =~ ^[a-z][a-z0-9-]+$ && $tag =~ ^[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || exit 1
[[ -f .env ]] || { echo 'Install production .env first.' >&2; exit 1; }
exec 9>/opt/meridian/.deploy.lock
flock -n 9 || { echo 'Another deploy is running.' >&2; exit 1; }
export ECR_REGISTRY=$registry ECR_REPOSITORY_PREFIX=$prefix IMAGE_TAG=$tag
docker compose config --quiet
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
trap 'docker logout "$registry" >/dev/null' EXIT
docker compose pull
# Protect the existing database before replacing application containers.
if docker compose ps --status running --services | grep -qx postgres; then
  bash scripts/backup_db.sh
fi
docker compose up -d --no-build --wait --wait-timeout 180
for port in 8001 8002 8003; do curl --fail --silent --show-error "http://127.0.0.1:$port/healthz"; done
curl --fail --silent --show-error http://127.0.0.1:8080/ > /dev/null
# Persist the exact release for cron and future compose commands.
sed -i '/^ECR_REGISTRY=/d; /^ECR_REPOSITORY_PREFIX=/d; /^IMAGE_TAG=/d' .env
printf '\nECR_REGISTRY=%s\nECR_REPOSITORY_PREFIX=%s\nIMAGE_TAG=%s\n' "$registry" "$prefix" "$tag" >> .env
chmod 600 .env
echo "Deployed $tag"
