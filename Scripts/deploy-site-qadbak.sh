#!/usr/bin/env bash
# Deploy Oriel marketing site to the Qadbak VPS webroot (openoriel.com).
# Usage:
#   bash Scripts/deploy-site-qadbak.sh
#   ORIEL_SITE_HOST=root@158.220.85.245 ORIEL_SITE_ROOT=/home/openoriel/public_html bash Scripts/deploy-site-qadbak.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${ORIEL_SITE_HOST:-root@158.220.85.245}"
DEST="${ORIEL_SITE_ROOT:-/home/openoriel/public_html}"

echo "-> rsync site/ → ${HOST}:${DEST}/"
rsync -avz --delete \
  --exclude '.DS_Store' \
  --exclude 'README.md' \
  "$ROOT/site/" \
  "${HOST}:${DEST}/"

echo "OK: deployed. Purge Cloudflare cache for openoriel.com if icons look stale."
echo "  curl -sI https://openoriel.com/assets/oriel-pulse-mark.svg | head -5"
