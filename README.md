# bmo_app

Frontend Flutter (web e iOS) do BMO. Acessa o bmo-server via Tailscale
(HTTPS via Caddy no hostname Tailscale); o QwenPaw fica atrás do
bmo-server, o frontend não fala com ele direto.

## Configuração de URLs

As URLs dos backends vêm de `--dart-define` (`lib/core/config/env.dart`):

| Variável | Default |
| --- | --- |
| `BMO_SERVER_URL` | `https://jedhais-mac-mini.taild5baed.ts.net` |
| `AGENT_ID` | `default` |

`BMO_SERVER_URL` precisa ser `https://` — o ATS do iOS bloqueia HTTP puro,
e uma assertion em debug falha no boot se a URL configurada não começar com
`https://`. Não adicionar exceções de ATS ao `Info.plist`.

## Build

```bash
flutter pub get

# Web (dev)
flutter run -d chrome

# Web (produção)
flutter build web --release \
  --dart-define=BMO_SERVER_URL=https://jedhais-mac-mini.taild5baed.ts.net

# iOS
flutter build ios \
  --dart-define=BMO_SERVER_URL=https://jedhais-mac-mini.taild5baed.ts.net
```

Os defaults do `env.dart` já apontam para o hostname Tailscale; o
`--dart-define` só é necessário para apontar para outro ambiente.

## Comandos

```bash
dart run build_runner build        # após mudar provider com @riverpod
dart run build_runner watch        # durante desenvolvimento ativo
flutter analyze                    # lint
```
