import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'file_stream_writer.dart';

/// Nativo (iOS): sempre disponível — grava em arquivo temporário.
bool get isFileStreamSaveAvailable => true;

/// Escrita sequencial com dart:io puro (File + RandomAccessFile).
///
/// O destino é um arquivo em NSTemporaryDirectory: iOS ainda não tem
/// seletor de destino (file_selector.getSaveLocation lança
/// UnimplementedError) — o passo 9 (share sheet) faz a entrega ao usuário.
/// Até lá, o purge do SO cobre qualquer parcial que escape do [abort].
///
/// Regra: parcial nunca sobrevive. Erro em [writeChunk] ou [finalize]
/// fecha o RAF e apaga o arquivo ANTES de propagar — todo caminho de saída
/// passa por lá, sem depender do caller. [abort] é idempotente e nunca
/// lança; depois de [finalize] é no-op (arquivo completo não é parcial).
class IoFileStreamWriter implements FileStreamWriter {
  IoFileStreamWriter._(this._file, this._raf);

  final File _file;
  RandomAccessFile? _raf;
  bool _finalized = false;

  static Future<IoFileStreamWriter> create(
    String suggestedName, {
    String? destinationDirectory,
  }) async {
    final file = File(
      destinationDirectory == null
          ? '${Directory.systemTemp.path}/bmo_download_'
              '${DateTime.now().microsecondsSinceEpoch}'
              '_${Random().nextInt(1 << 32)}'
              '_${_safeName(suggestedName)}'
          : '$destinationDirectory/${_safeName(suggestedName)}',
    );
    // Na pasta do usuário, truncar um arquivo existente seria perda
    // silenciosa — o caller recebe null e reporta o item como falho.
    if (destinationDirectory != null && await file.exists()) {
      throw FileSystemException('File already exists', file.path);
    }
    final raf = await file.open(mode: FileMode.writeOnly);
    return IoFileStreamWriter._(file, raf);
  }

  @override
  Future<void> writeChunk(Uint8List bytes) async {
    final raf = _raf;
    if (raf == null) {
      throw StateError('writeChunk após finalize/abort');
    }
    try {
      await raf.writeFrom(bytes);
    } catch (_) {
      await abort(); // parcial nunca sobrevive, mesmo se o caller esquecer.
      rethrow;
    }
  }

  @override
  Future<void> finalize() async {
    final raf = _raf;
    if (raf == null) {
      throw StateError('finalize após finalize/abort');
    }
    try {
      await raf.close();
    } catch (_) {
      _raf = null;
      await _deleteQuietly(); // close falhou: parcial não sobrevive.
      rethrow;
    }
    _raf = null;
    _finalized = true;
  }

  @override
  Future<void> abort() async {
    if (_finalized) return;
    final raf = _raf;
    _raf = null;
    if (raf != null) {
      try {
        await raf.close();
      } catch (_) {
        // close falhou — o delete abaixo remove o parcial de qualquer forma.
      }
    }
    await _deleteQuietly();
  }

  /// Apaga sem reclamar — falha de limpeza não pode quebrar o fechamento.
  Future<void> _deleteQuietly() async {
    try {
      if (await _file.exists()) await _file.delete();
    } catch (_) {
      // Melhor esforço: NSTemporaryDirectory é purgado pelo SO.
    }
  }
}

/// O nome vem de item.fileName (controle do usuário) e entra num path —
/// separadores viram '_' para o arquivo não escapar do diretório temporário.
String _safeName(String suggestedName) =>
    suggestedName.replaceAll(RegExp(r'[/\\]'), '_');

Future<FileStreamWriter?> openFileStreamWriter(
  String suggestedName, {
  String? destinationDirectory,
}) async {
  try {
    return await IoFileStreamWriter.create(
      suggestedName,
      destinationDirectory: destinationDirectory,
    );
  } catch (_) {
    // Sem disco/nome inválido/arquivo já existente na pasta — caller trata.
    return null;
  }
}
