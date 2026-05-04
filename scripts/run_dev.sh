#!/usr/bin/env bash
# Roda o app apontando pra backends locais (mesma máquina dos servidores).
flutter run -d chrome \
  --dart-define=QWENPAW_URL=http://localhost:8088 \
  --dart-define=BMO_SERVER_URL=http://localhost:8089
