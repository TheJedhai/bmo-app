export 'video_source_stub.dart'
    if (dart.library.js_interop) 'video_source_web.dart';

/// Fonte de vídeo com recurso a liberar.
///
/// Ponte entre bytes decifrados e o [VideoPlayerController]. Web: blob URL
/// (revogado no [dispose]). Nativo: arquivo temporário com os bytes
/// decifrados (apagado no [dispose]).
///
/// O call site nunca adivinha O QUE limpar — [dispose] faz a limpeza
/// inteira da plataforma. Esquecer o dispose vaza blob URL (web) ou deixa
/// conteúdo de cofre em disco (nativo).
abstract class VideoSource {
  /// URI para passar a `VideoPlayerController.networkUrl`.
  Uri get uri;

  /// Libera o recurso de origem. Seguro chamar mais de uma vez.
  void dispose();
}
