#!/usr/bin/env bash
# Roda o app apontando pros backends via Tailscale (do macbook).
# TODO: substituir <TAILSCALE_IP> pelo IP real do Mac mini na Tailscale.
flutter run -d chrome \
  --dart-define=QWENPAW_URL=http://<TAILSCALE_IP>:8088 \
  --dart-define=BMO_SERVER_URL=http://<TAILSCALE_IP>:8089
