# bmo_app

Frontend Flutter web do BMO. Roda no navegador (desktop e mobile),
acessa dois backends via Tailscale: QwenPaw (8088) e bmo-server (8089).

## Stack

- Flutter web (canal stable, Dart SDK ^3.11.5)
- Riverpod para state management (`flutter_riverpod` + code generation)
- `http` para REST
- `flutter_svg` para assets vetoriais
- `url_launcher` para abrir o Console do QwenPaw em nova aba

## Estrutura

```
lib/
├── main.dart              # entry point
├── app.dart               # MaterialApp + tema + frame
├── core/
│   ├── theme/             # BmoTheme, BmoColors
│   └── widgets/           # widgets compartilhados (BmoFrame, etc)
└── features/
    ├── chat/              # aba Chat (QwenPaw API)
    ├── tasks/             # aba Tarefas (bmo-server)
    └── ...                # uma pasta por feature
```

Cada feature é autocontida: screen + providers + models + widgets locais.
State global de tema/navegação fica em `core/`.

## Design — paleta BMO

Definida em `lib/core/theme/bmo_theme.dart`. Não inventar cores novas
sem necessidade real:

- `bodyGreen` `#8BC9A3` — borda externa (cabeça do BMO)
- `screenBg` `#1E1F23` — tela interna
- `screenBgElevated` `#26272C` — cards/painéis
- `accentGreen` `#B8E0C2` — ativo/online
- `accentYellow` `#E8D8A0` — detalhes
- `textPrimary/Secondary/Muted` — hierarquia de texto

## Tipografia

- **PressStart2P** APENAS em headers (display*, headline*, title\*).
  Pesa demais em corpo de texto.
- **Inter** para body, labels, UI normal.

## Layout

- `BmoFrame` cobre a viewport: borda verde + screen escura no meio
- Breakpoint mobile: `< 600px` (definido em `bmo_frame.dart` como `_kMobileBreakpoint`)
- Padding da borda muda entre mobile (12) e desktop (28)
- Web only — não otimizar para iOS/Android nativo

## Comandos

```bash
flutter pub get
flutter run -d chrome              # dev
flutter build web                  # produção
dart run build_runner build        # após mudar provider com @riverpod
dart run build_runner watch        # durante desenvolvimento ativo
flutter analyze                    # lint
```

## Convenções

- Riverpod: usar `@riverpod` annotation + code generation, não criar Provider manualmente
- Toda chamada HTTP vai por um `repository` no `features/{feature}/data/`
- Nada de `print` — usar `debugPrint` ou logger
- Não usar setState em widgets que já estão no Riverpod tree
- Imports relativos dentro do mesmo feature, absolutos entre features

## Não fazer

- Não adicionar dependência sem checar tamanho do bundle web
- Não inventar cores fora da paleta BMO
- Não usar PressStart2P em texto corrido
- Não hardcodar URLs dos backends — devem vir de config (env ou similar)
- Não commitar `build/`, `.dart_tool/`, `pubspec.lock` se mudar só por timestamp

## Workflow com Claude Code

- Etapas pequenas, no mínimo 1 commit por sub-item
- Após mudar providers anotados, rodar `build_runner` antes de testar
- Plan mode antes de tarefas que tocam múltiplas features
