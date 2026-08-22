// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import 'file_range_reader.dart';

/// Contadores — prova de que o leitor obtém o blob UMA vez e de que não há
/// requisição por chunk (a medida pedida para o upload de arquivo grande).
int fileRangeReaderOpenedCount = 0;
int fileRangeReaderBlobFetches = 0;

/// Leitor web: re-hidrata o blob do URL UMA vez (handle, não bytes) e fatia
/// por chunk via `Blob.slice`, lendo só a fatia. Nenhum XHR por chunk.
///
/// A razão de existir: `XFile.openRead` da cross_file re-hidrata o blob via
/// XHR a CADA chamada (o `_browserBlob` só é cacheado quando construído com
/// bytes), e um XHR contra o blob URL materializa o arquivo INTEIRO por
/// leitura — inviável para upload repetido de arquivo grande (issue #91867).
/// [dispose] é no-op: não criamos blob URL, o [XFile] já o detém.
class WebFileRangeReader implements FileRangeReader {
  WebFileRangeReader._(this._path);

  final String _path;
  html.Blob? _blob;

  /// Re-hidrata o blob do [path] uma única vez; as chamadas seguintes usam o
  /// handle cacheado.
  Future<html.Blob> _ensureBlob() async {
    final cached = _blob;
    if (cached != null) return cached;

    final completer = Completer<html.Blob>();
    late html.HttpRequest request;
    request = html.HttpRequest()
      ..open('get', _path, async: true)
      ..responseType = 'blob'
      ..onLoad.listen((_) => completer.complete(request.response! as html.Blob))
      ..onError.listen((html.ProgressEvent e) {
        if (e.type == 'error') {
          completer.completeError(
            Exception('Could not load Blob from its URL. Has it been revoked?'),
          );
        }
      })
      ..send();

    fileRangeReaderBlobFetches++;
    final blob = await completer.future;
    _blob = blob;
    return blob;
  }

  @override
  Future<Uint8List> readRange(int start, int end) async {
    final blob = await _ensureBlob();
    // Blob.slice é um view O(1) — não materializa dados; [end] além do
    // tamanho fecha na borda do blob, [start] no início. Lemos só a fatia.
    final slice = blob.slice(start, end);
    final reader = html.FileReader();
    reader.readAsArrayBuffer(slice);
    await reader.onLoadEnd.first;
    final result = reader.result;
    if (result is! Uint8List) {
      throw Exception('Cannot read Blob slice bytes.');
    }
    return result;
  }

  @override
  void dispose() {
    // Sem blob URL criado aqui — nada a revogar. Soltar a referência deixa o
    // GC recolher o handle.
  }
}

/// Abre um [FileRangeReader] para [file]. Uma vez — não por chunk.
///
/// `async` converte erros de re-hidratar o blob (ex.: URL revogado) em erro
/// do Future, capturável pelo call site com `await`.
Future<FileRangeReader> openFileRangeReader(XFile file) async {
  fileRangeReaderOpenedCount++;
  return WebFileRangeReader._(file.path);
}
