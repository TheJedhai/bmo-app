import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'video_source.dart';

/// Fonte nativa (iOS): grava os bytes decifrados em arquivo temporário e
/// apaga no [dispose].
///
/// dart:io puro — path_provider é desnecessário, [Directory.systemTemp] já
/// é o NSTemporaryDirectory do iOS, que o SO também purga se o app morrer
/// antes do dispose.
class IoVideoSource implements VideoSource {
  IoVideoSource._(this._file);

  final File _file;

  static Future<IoVideoSource> create(
    Uint8List bytes,
    String mimeType,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/bmo_video_'
      '${DateTime.now().microsecondsSinceEpoch}'
      '_${Random().nextInt(1 << 32)}'
      '${_extensionFor(mimeType)}',
    );
    try {
      // flush: true — dados em disco antes do write retornar.
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Erro no meio da gravação: apagar o parcial antes de propagar.
      await _deleteQuietly(file);
      rethrow;
    }
    return IoVideoSource._(file);
  }

  @override
  Uri get uri => _file.uri;

  @override
  void dispose() {
    // Dispose não pode await. unlink funciona com o arquivo aberto (POSIX):
    // o AVPlayer segue lendo pelo fd, espaço liberado quando ele fechar.
    _deleteQuietly(_file);
  }
}

/// Apaga sem reclamar — falha de limpeza não pode quebrar o fechamento.
Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Melhor esforço: NSTemporaryDirectory é purgado pelo SO.
  }
}

/// O AVPlayer escolhe o decoder pelo tipo do arquivo; extensão certa ajuda.
String _extensionFor(String mimeType) {
  switch (mimeType) {
    case 'video/mp4':
      return '.mp4';
    case 'video/quicktime':
      return '.mov';
    case 'video/webm':
      return '.webm';
    case 'video/x-matroska':
      return '.mkv';
    default:
      return '.tmp';
  }
}

Future<VideoSource> createVideoSource(Uint8List bytes, String mimeType) =>
    IoVideoSource.create(bytes, mimeType);
