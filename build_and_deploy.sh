#!/usr/bin/env bash
set -euo pipefail

REPO=~/Documents/bmo-app
WWW=/opt/homebrew/var/www/bmo

BMO_SERVER_URL="http://100.113.90.23:8089"
QWENPAW_URL="http://100.113.90.23:8088"
AGENT_ID="default"

cd "$REPO"

echo "==> flutter build web"
flutter build web --release \
  --dart-define=BMO_SERVER_URL="$BMO_SERVER_URL" \
  --dart-define=QWENPAW_URL="$QWENPAW_URL" \
  --dart-define=AGENT_ID="$AGENT_ID"

echo "==> sincronizando para $WWW"
rsync -a --delete "$REPO/build/web/" "$WWW/"

echo "==> recarregando nginx"
nginx -s reload

echo "==> pronto: http://100.113.90.23:8090"
