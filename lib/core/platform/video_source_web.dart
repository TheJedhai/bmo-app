// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'video_source.dart';

/// Fonte web: blob URL criado a partir dos bytes decifrados.
///
/// [dispose] revoga o blob URL — esquecer aqui é vazamento silencioso de
/// memória do navegador.
class WebVideoSource implements VideoSource {
  WebVideoSource(Uint8List bytes, String mimeType)
      : uri = Uri.parse(
          html.Url.createObjectUrl(html.Blob([bytes], mimeType)),
        );

  @override
  final Uri uri;

  @override
  void dispose() {
    html.Url.revokeObjectUrl(uri.toString());
  }
}

/// Cria a fonte de vídeo desta plataforma.
///
/// `async` converte erros de criação do blob (ex.: falta de memória) em
/// erro do Future, capturável pelo call site com `await`.
Future<VideoSource> createVideoSource(Uint8List bytes, String mimeType) async {
  return WebVideoSource(bytes, mimeType);
}
