#!/usr/bin/env bash
# ~/Documents está no iCloud, que carimba com.apple.provenance nos artefatos
# e quebra o codesign do Flutter.framework no build de iOS.
# Artefatos ficam fora do iCloud via symlink.
# ATENÇÃO: `flutter clean` apaga os symlinks de build/ e .dart_tool/.
# Rode este script depois de todo clean.
set -euo pipefail
REPO=~/Documents/bmo-app
EXT=~/dev/bmo-app-ext

link() {
  local target="$1" path="$2"
  mkdir -p "$target"
  [ -L "$path" ] && return 0
  [ -e "$path" ] && rm -rf "$path"
  ln -s "$target" "$path"
  echo "relinked: $path -> $target"
}

link "$EXT/build"     "$REPO/build"
link "$EXT/dart_tool" "$REPO/.dart_tool"
link "$EXT/pods"      "$REPO/ios/Pods"
