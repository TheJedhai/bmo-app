#!/usr/bin/env bash
# ~/Documents está no iCloud, que carimba com.apple.provenance nos artefatos
# e quebra o codesign do Flutter.framework no build de iOS.
# Só build/ precisa sair do iCloud — foi ele que quebrou o codesign.
#
# NÃO symlinkar .dart_tool (package_config.json usa caminhos absolutos e a
# análise quebra) nem ios/Pods (o Xcode resolve o link e polui
# contents.xcworkspacedata com um caminho de máquina).
#
# ATENÇÃO: `flutter clean` apaga o symlink de build/. Rode isto depois.
set -euo pipefail
REPO=~/Documents/bmo-app
TARGET=~/dev/bmo-app-ext/build

mkdir -p "$TARGET"
if [ -L "$REPO/build" ] && [ "$(readlink "$REPO/build")" = "$TARGET" ]; then
  echo "build/ já linkado"
else
  rm -rf "$REPO/build"
  ln -s "$TARGET" "$REPO/build"
  echo "relinked: $REPO/build -> $TARGET"
fi

cd "$REPO" && flutter pub get
