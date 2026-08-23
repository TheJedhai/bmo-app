#!/usr/bin/env bash
# Gera o .ipa do BMO para instalar pelo AltStore.
#
# Por que empacotar à mão: `flutter build ipa` tenta exportar para a App
# Store, o que exige certificado "iOS Distribution" e perfil de App Store —
# coisas que o Personal Team (conta Apple gratuita) não pode criar. O
# archive é gerado, mas a exportação falha. Um .ipa é só um zip com uma
# pasta Payload dentro, então montamos direto do .app.
#
# Nota: build/ é symlink para fora do iCloud (ver relink.sh).
set -euo pipefail

REPO=~/Documents/bmo-app
APP="$REPO/build/ios/iphoneos/Runner.app"
OUT=~/Desktop/BMO.ipa
STAGE=/tmp/bmo-ipa

cd "$REPO"

echo "==> garantindo symlink de build/"
"$REPO/dev/relink.sh"

echo "==> compilando release"
flutter build ios --release

[ -d "$APP" ] || { echo "ERRO: $APP não existe"; exit 1; }

echo "==> empacotando"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

# sanity: sem os frameworks o app instala e não abre
if ! find "$STAGE/Payload/Runner.app/Frameworks" -name 'App.framework' -maxdepth 1 | grep -q .; then
  echo "ERRO: App.framework ausente — pacote incompleto"
  exit 1
fi

rm -f "$OUT"
(cd "$STAGE" && zip -qr "$OUT" Payload)
rm -rf "$STAGE"

echo
echo "==> pronto: $OUT"
ls -lh "$OUT"
echo
echo "AirDrop para o iPhone, depois AltStore > My Apps > + > BMO.ipa"
