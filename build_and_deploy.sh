#!/usr/bin/env bash
set -euo pipefail

REPO=~/Documents/bmo-app
WWW=/opt/homebrew/var/www/bmo
CADDYFILE_SRC="$REPO/deploy/Caddyfile"
CADDYFILE_DEST=/opt/homebrew/etc/Caddyfile

BMO_SERVER_URL="https://jedhais-mac-mini.taild5baed.ts.net"
QWENPAW_URL="http://100.113.90.23:8088"

cd "$REPO"

echo "==> flutter build web"
flutter build web --release \
  --dart-define=BMO_SERVER_URL="$BMO_SERVER_URL" \
  --dart-define=QWENPAW_URL="$QWENPAW_URL"

echo "==> validando Caddyfile"
caddy fmt --overwrite "$CADDYFILE_SRC"
caddy validate --config "$CADDYFILE_SRC"

echo "==> sincronizando build para $WWW"
mkdir -p "$WWW"
rsync -a --delete "$REPO/build/web/" "$WWW/"

echo "==> aplicando Caddyfile"
cp "$CADDYFILE_SRC" "$CADDYFILE_DEST"

echo "==> recarregando caddy (brew services)"
brew services reload caddy

echo "==> pronto: $BMO_SERVER_URL"