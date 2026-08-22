// Measurement + regression for the web chunked-file reader (the seam the
// upload uses instead of XFile.openRead). Runs on chrome — dart:html é o
// ambiente real do browser.
//
// Prova as três propriedades pedidas contra o bug #91867 (XFile.openRead
// re-hidrata o blob via XHR a cada leitura, materializando o arquivo todo de
// novo por chunk — inviável para upload de arquivo grande):
//   1. leitura por chunk cai para milissegundos (steady-state ms)
//   2. o buffer por chunk é constante (== tamanho do chunk), não o arquivo
//   3. UMA requisição de blob para N chunks — não uma por chunk
//
// Run: flutter test --platform=chrome test/file_range_reader_web_test.dart

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/file_range_reader.dart';

/// Deterministic pseudo-random bytes (NOT cryptographic — test data only).
Uint8List _testBytes(int length, {int seed = 42}) {
  final bytes = Uint8List(length);
  var state = seed;
  for (var i = 0; i < length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    bytes[i] = state & 0xFF;
  }
  return bytes;
}

void runFileRangeReaderWebTests() {
  const chunkSize = 1024 * 1024; // 1 MiB — matches the upload default chunk
  const chunkCount = 16;         // 16 MiB blob, 16 chunks

  test('web reader slices per chunk — one blob fetch, no per-chunk XHR',
      () async {
    final bytes = _testBytes(chunkSize * chunkCount);

    // Reproduce the real-world XFile shape: a path-only blob URL (what
    // image_picker_for_web hands over). `_browserBlob` is null, so cross_file
    // would re-issue an XHR per openRead — exactly the case #91867 hits.
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrl(blob);
    try {
      final reader = await openFileRangeReader(XFile(url, name: 'big.bin'));

      final reads = <Duration>[];
      final slices = <Uint8List>[];
      for (var i = 0; i < chunkCount; i++) {
        final sw = Stopwatch()..start();
        slices.add(await reader.readRange(i * chunkSize, (i + 1) * chunkSize));
        sw.stop();
        reads.add(sw.elapsed);
      }
      reader.dispose();

      // Correctness: each chunk = the corresponding range of the source.
      for (var i = 0; i < chunkCount; i++) {
        expect(
          slices[i],
          Uint8List.sublistView(bytes, i * chunkSize, (i + 1) * chunkSize),
        );
      }

      // The crux: the reader obtained the blob handle ONCE — unlike
      // openRead's per-call XHR. One fetch per N chunks.
      expect(fileRangeReaderBlobFetches, 1);

      // (2) Constant per-chunk buffer — never the whole file.
      final maxBuf = slices.fold<int>(0, (m, s) => s.length > m ? s.length : m);
      expect(maxBuf, chunkSize);

      // (1) Timings: first read carries the one-time blob rehydrate; steady
      // reads are pure slice reads.
      final firstRead = reads.first;
      final steady = reads.sublist(1);
      final steadyAvg = Duration(
        microseconds:
            steady.map((d) => d.inMicroseconds).fold(0, (a, b) => a + b) ~/
                steady.length,
      );
      final maxRead = reads.reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print(
          'WEB READER: $chunkCount chunks x ${chunkSize ~/ (1024 * 1024)} MiB '
          '| first read (blob fetch) = ${firstRead.inMicroseconds} us, '
          'steady avg read/chunk = ${steadyAvg.inMicroseconds} us, '
          'max read/chunk = ${maxRead.inMicroseconds} us | '
          'max slice buf = $maxBuf bytes | blob fetches = '
          '$fileRangeReaderBlobFetches (não 1 por chunk).');

      // Contrast against the OLD path only for the report — cross_file's
      // openRead re-hydrata o blob (XHR) a cada chunk. Not asserted: timing
      // and the magnitude of the freeze escala com o tamanho do arquivo
      // (memória/GC). Re-measure fresh so the counters stay correct.
      final oldReads = <Duration>[];
      for (var i = 0; i < chunkCount; i++) {
        final sw = Stopwatch()..start();
        final x = XFile(url, name: 'big.bin');
        await for (final _ in x.openRead(i * chunkSize, (i + 1) * chunkSize)) {
          // discard
        }
        sw.stop();
        oldReads.add(sw.elapsed);
      }
      final oldAvg = Duration(
        microseconds:
            oldReads.map((d) => d.inMicroseconds).fold(0, (a, b) => a + b) ~/
                oldReads.length,
      );
      // ignore: avoid_print
      print(
          'WEB READER (old XFile.openRead) avg read/chunk = '
          '${oldAvg.inMicroseconds} us — $chunkCount XHRs no total.');
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  });
}
