/// Ponto único de entrada do vault para o resto do app.
///
/// O vault é web-only (WebCrypto, File System Access API, Canvas/Video,
/// dart:ui_web). Este conditional export corta o feature inteiro no import:
/// builds sem js_interop (iOS/Android/desktop) compilam o stub; builds web
/// compilam o vault real. Nenhum arquivo de dentro do vault pode ser
/// importado diretamente fora daqui.
library;

export 'vault_entry_stub.dart'
    if (dart.library.js_interop) 'vault_entry_web.dart';
