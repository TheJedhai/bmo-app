import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'file_range_reader.dart';

/// Contadores — espelhados na branch web para o import condicional resolver o
/// mesmo símbolo em qualquer plataforma (mesmo padrão de video_source).
int fileRangeReaderOpenedCount = 0;
int fileRangeReaderBlobFetches = 0;

/// Leitor nativo: [XFile.openRead] com faixa já lê só `[start, end)` do
/// dart:io [File] — comportamento existente, sem mudança.
class IoFileRangeReader implements FileRangeReader {
  IoFileRangeReader._(this._file);

  final XFile _file;

  @override
  Future<Uint8List> readRange(int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _file.openRead(start, end)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  void dispose() {}
}

/// Abre um [FileRangeReader] para [file]. Uma vez — não por chunk.
Future<FileRangeReader> openFileRangeReader(XFile file) async =>
    IoFileRangeReader._(file);
