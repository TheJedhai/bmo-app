#!/usr/bin/env bash
set -euo pipefail

REPO=~/Documents/bmo-app
WWW=/opt/homebrew/var/www/bmo
CADDYFILE_DEST=/opt/homebrew/etc/Caddyfile

BMO_SERVER_URL="https://jedhais-mac-mini.taild5baed.ts.net"
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

echo "==> aplicando Caddyfile"
cp "$REPO/deploy/Caddyfile" "$CADDYFILE_DEST"
caddy fmt --overwrite "$CADDYFILE_DEST"
caddy validate --config "$CADDYFILE_DEST"
caddy reload --config "$CADDYFILE_DEST"

echo "==> recarregando nginx"
nginx -s reload

echo "==> pronto: https://jedhais-mac-mini.taild5baed.ts.net"
