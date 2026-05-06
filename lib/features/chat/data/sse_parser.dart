import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

const _dataPrefix = 'data: ';

/// Decodifica um stream SSE em mapas JSON.
///
/// Cada evento é assumido como uma linha "data: {json}" — formato emitido
/// pelo bmo-server. Linhas sem prefixo são ignoradas. JSON inválido vira
/// warning no log e a linha é descartada (não derruba o stream).
Stream<Map<String, dynamic>> parseSseStream(Stream<List<int>> byteStream) {
  return byteStream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .transform(StreamTransformer<String, Map<String, dynamic>>.fromHandlers(
    handleData: (line, sink) {
      if (!line.startsWith(_dataPrefix)) return;
      final payload = line.substring(_dataPrefix.length);
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          sink.add(decoded);
        } else {
          developer.log(
            'SSE payload não é objeto JSON: $payload',
            name: 'sse_parser',
            level: 900,
          );
        }
      } catch (e) {
        developer.log(
          'SSE JSON inválido: $payload (erro: $e)',
          name: 'sse_parser',
          level: 900,
        );
      }
    },
  ));
}
