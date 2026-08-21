// ignore_for_file: lines_longer_than_80_chars

// Native branch of the file stream writer seam (VM only).
//
// IoFileStreamWriter contract — partial never survives:
// 1. finalize after chunks → file on disk with the exact bytes
// 2. abort mid-write → no file left behind
// 3. abort after finalize → no-op, file intact
// 4. abort is idempotent and never throws
// 5. writeChunk after abort → StateError (lifecycle misuse)
// 6. path separators in the name cannot escape the temp dir
//
// Run: flutter test test/file_stream_writer_stub_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/file_stream_writer.dart';

List<File> _downloadFiles() => Directory.systemTemp
    .listSync()
    .whereType<File>()
    .where((f) => f.path.contains('bmo_download_'))
    .toList();

void main() {
  group('branch nativa (dart:io) — VM only', skip: kIsWeb, () {
    test('finalize grava os bytes exatos no arquivo', () async {
      final before = _downloadFiles().length;

      final writer = await openFileStreamWriter('relatório.txt');
      expect(writer, isNotNull);
      await writer!.writeChunk(Uint8List.fromList([1, 2, 3]));
      await writer.writeChunk(Uint8List.fromList([4, 5]));
      await writer.finalize();

      final files = _downloadFiles();
      expect(files.length, before + 1);
      expect(await files.last.readAsBytes(), [1, 2, 3, 4, 5]);
      expect(files.last.path.endsWith('relatório.txt'), isTrue);

      files.last.deleteSync(); // limpeza do teste
    });

    test('abort no meio da gravação não deixa arquivo', () async {
      final before = _downloadFiles().length;

      final writer = await openFileStreamWriter('parcial.bin');
      await writer!.writeChunk(Uint8List.fromList([1, 2, 3]));
      await writer.abort();

      expect(_downloadFiles().length, before);
    });

    test('abort depois de finalize é no-op — arquivo fica', () async {
      final before = _downloadFiles().length;

      final writer = await openFileStreamWriter('completo.bin');
      await writer!.writeChunk(Uint8List.fromList([1]));
      await writer.finalize();
      await writer.abort();

      expect(_downloadFiles().length, before + 1);
      _downloadFiles().last.deleteSync();
    });

    test('abort repetido nunca lança', () async {
      final writer = await openFileStreamWriter('duplo.bin');
      await writer!.abort();
      await writer.abort();
      await writer.abort();
    });

    test('writeChunk depois de abort lança StateError', () async {
      final writer = await openFileStreamWriter('errado.bin');
      await writer!.abort();
      expect(
        () => writer.writeChunk(Uint8List.fromList([1])),
        throwsStateError,
      );
    });

    test('separadores de path no nome não escapam do temp', () async {
      final writer = await openFileStreamWriter('a/../b.txt');
      await writer!.writeChunk(Uint8List.fromList([1]));
      await writer.finalize();

      final file = _downloadFiles().last;
      expect(file.parent.path, Directory.systemTemp.path);

      file.deleteSync();
    });

    test('destinationDirectory grava solto na pasta com o nome original',
        () async {
      final dir = await Directory.systemTemp.createTemp('bmo_batch_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final writer = await openFileStreamWriter(
        'foto.jpg',
        destinationDirectory: dir.path,
      );
      expect(writer, isNotNull);
      await writer!.writeChunk(Uint8List.fromList([7, 8, 9]));
      await writer.finalize();

      final file = File('${dir.path}/foto.jpg');
      expect(await file.readAsBytes(), [7, 8, 9]);
      // Nada caiu no temp global.
      expect(_downloadFiles(), isEmpty);
    });

    test('destinationDirectory não sobrescreve arquivo existente', () async {
      final dir = await Directory.systemTemp.createTemp('bmo_batch_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final existing = File('${dir.path}/dupla.txt');
      await existing.writeAsBytes([1, 2, 3]);

      final writer = await openFileStreamWriter(
        'dupla.txt',
        destinationDirectory: dir.path,
      );
      expect(writer, isNull, reason: 'colisão vira null, não truncamento');

      expect(await existing.readAsBytes(), [1, 2, 3],
          reason: 'conteúdo existente intocado');
    });

    test('abort na pasta destino apaga o parcial', () async {
      final dir = await Directory.systemTemp.createTemp('bmo_batch_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final writer = await openFileStreamWriter(
        'parcial.jpg',
        destinationDirectory: dir.path,
      );
      await writer!.writeChunk(Uint8List.fromList([1]));
      await writer.abort();

      expect(dir.listSync(), isEmpty);
    });
  });
}
