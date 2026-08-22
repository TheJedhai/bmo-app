// Roteamento por mime + vazamento de temp + entrega na pasta, branch
// nativa da costura file_download (VM only).
//
// Runs on the host VM (macOS flutter_tester): gal has no plugin there, so
// the access check fails (generic path) or, with the seam set to true, the
// put itself fails — exactly the failure paths that must still delete the
// decrypted temp file.
//
// Compilado apenas no VM via import condicional em
// file_download_stub_test.dart (chrome compila
// file_download_stub_test_cases_web.dart, vazio).
//
// Run: flutter test test/file_download_stub_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/file_download.dart';

List<String> _tempDownloads() => Directory.systemTemp
    .listSync()
    .where((e) => e.path.contains('bmo_download_'))
    .map((e) => e.path)
    .toList();

void runFileDownloadStubTests() {
  // Os caminhos de falha passam por MethodChannels (gal/file_picker sem
  // plugin no flutter_tester) — precisam do binding inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalAccessCheck = fileDownloadGalleryAccessCheck;
  tearDown(() {
    fileDownloadGalleryAccessCheck = originalAccessCheck;
  });

  group('singleItemDownloadMode (roteamento nativo)', skip: kIsWeb, () {
    test('mídia vira streamToGallery em QUALQUER tamanho — sem gate', () {
      for (final mime in ['image/png', 'image/heic', 'video/mp4']) {
        for (final size in [0, 25 * 1024 * 1024, 100 * 1024 * 1024]) {
          expect(
            singleItemDownloadMode(originalSize: size, mimeType: mime),
            SingleItemDownloadMode.streamToGallery,
            reason: '$mime com ${size ~/ 1048576} MiB',
          );
        }
      }
    });

    test('não-mídia vira streamToFolder em QUALQUER tamanho — sem gate', () {
      for (final mime in ['application/pdf', 'text/plain', 'application/zip']) {
        for (final size in [0, 25 * 1024 * 1024, 100 * 1024 * 1024]) {
          expect(
            singleItemDownloadMode(originalSize: size, mimeType: mime),
            SingleItemDownloadMode.streamToFolder,
            reason: '$mime com ${size ~/ 1048576} MiB',
          );
        }
      }
    });
  });

  group('deliverFileToGallery (entrega do streaming)', skip: kIsWeb, () {
    test('put de vídeo falha: mensagem chega e temp morre em finally', () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      final temp = File(
        '${Directory.systemTemp.path}/bmo_download_test_video.mp4',
      );
      await temp.writeAsBytes(List.generate(100, (i) => i % 256));

      // Sem plugin do gal no tester: o put falha — é o caminho que tem que
      // apagar o temp mesmo assim.
      final error = await deliverFileToGallery(
        filePath: temp.path,
        fileName: 'bmo-video-1.mp4',
        mimeType: 'video/mp4',
      );

      expect(error, isNotNull, reason: 'erro do put chega ao caller');
      expect(fileDownloadGalVideoCount, 1, reason: 'video routes to putVideo');
      expect(fileDownloadGalImageCount, 0);
      expect(fileDownloadTempCreatedCount, 1,
          reason: 'temp counted before put');
      expect(fileDownloadTempDeletedCount, 1,
          reason: 'finally deletes even on put failure');
      expect(await temp.exists(), isFalse, reason: 'temp apagado');
      expect(_tempDownloads(), before,
          reason: 'no bmo_download_* file left behind');
    });

    test('put de imagem falha: temp morre em finally também', () async {
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;

      final temp = File(
        '${Directory.systemTemp.path}/bmo_download_test_image.png',
      );
      await temp.writeAsBytes([1, 2, 3, 4]);

      final error = await deliverFileToGallery(
        filePath: temp.path,
        fileName: 'bmo-image-1.png',
        mimeType: 'image/png',
      );

      expect(error, isNotNull);
      expect(fileDownloadTempCreatedCount, 1);
      expect(fileDownloadTempDeletedCount, 1);
      expect(await temp.exists(), isFalse);
    });
  });

  group('ensureGalleryAccess', skip: kIsWeb, () {
    test('sem plugin no tester: checagem falha e vira mensagem', () async {
      final error = await ensureGalleryAccess();
      expect(error, isNotNull);
    });

    test('seam concedendo acesso: null', () async {
      fileDownloadGalleryAccessCheck = () async => true;
      expect(await ensureGalleryAccess(), isNull);
    });
  });

  group('downloadBytes (bytes em memória)', skip: kIsWeb, () {
    test('image mime routes to gal, access denied leaves no temp', () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      // Default seam: no gal plugin on the tester, access check fails.
      await downloadBytesNative(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'bmo-image-1.png',
        mimeType: 'image/png',
      );

      // Contagem conta o PUT (entrega), não o ramo: acesso negado não chega
      // ao putImageBytes, então o contador fica 0.
      expect(fileDownloadGalImageCount, 0,
          reason: 'acesso negado: nem chega ao putImageBytes');
      expect(fileDownloadGalVideoCount, 0);
      expect(fileDownloadTempCreatedCount, 0,
          reason: 'no temp before access granted');
      expect(_tempDownloads(), before);
    });

    test('image with access granted: putImageBytes, sem temp em disco',
        () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      // Access granted; sem plugin do gal no tester o putImageBytes falha.
      // O que importa: bytes vão por putImageBytes, NENHUM temp é criado.
      fileDownloadGalleryAccessCheck = () async => true;
      await downloadBytesNative(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'bmo-image-2.png',
        mimeType: 'image/png',
      );

      expect(fileDownloadGalImageCount, 1, reason: 'image goes to putImageBytes');
      expect(fileDownloadGalVideoCount, 0);
      expect(fileDownloadTempCreatedCount, 0,
          reason: 'bytes em memória não passam por disco');
      expect(fileDownloadTempDeletedCount, 0);
      expect(_tempDownloads(), before);
    });

    test('video with access granted: put failure deletes the temp file',
        () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      // Access granted, put fails: gal plugin is missing on the tester.
      fileDownloadGalleryAccessCheck = () async => true;
      await downloadBytesNative(
        bytes: Uint8List.fromList(List.generate(100, (i) => i % 256)),
        fileName: 'bmo-video-1.mp4',
        mimeType: 'video/mp4',
      );

      expect(fileDownloadGalVideoCount, 1, reason: 'video routes to gal');
      expect(fileDownloadTempCreatedCount, 1,
          reason: 'temp written before put');
      expect(fileDownloadTempDeletedCount, 1,
          reason: 'finally deletes even on put failure');
      expect(_tempDownloads(), before,
          reason: 'no bmo_download_* file left behind');
    });

    test('video with access denied never writes temp', () async {
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      await downloadBytesNative(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'bmo-video-2.mov',
        mimeType: 'video/quicktime',
      );

      expect(fileDownloadTempCreatedCount, 0);
      expect(fileDownloadTempDeletedCount, 0,
          reason: 'no file, nothing to delete');
      expect(_tempDownloads(), before);
    });

    test('non-media mime grava direto na pasta escolhida, sem file_saver',
        () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;

      final originalPicker = fileBatchFolderPicker;
      final originalStart = fileBatchFolderStartAccess;
      final originalStop = fileBatchFolderStopAccess;
      addTearDown(() {
        fileBatchFolderPicker = originalPicker;
        fileBatchFolderStartAccess = originalStart;
        fileBatchFolderStopAccess = originalStop;
      });

      final dir = await Directory.systemTemp.createTemp('bmo_folder_');
      addTearDown(() => dir.deleteSync(recursive: true));
      var stops = 0;
      fileBatchFolderPicker = () async => dir.path;
      fileBatchFolderStartAccess = (_) async => true;
      fileBatchFolderStopAccess = (_) async => stops++;

      final bytes = List.generate(200, (i) => i % 256);
      await downloadBytesNative(
        bytes: Uint8List.fromList(bytes),
        fileName: 'relatorio.pdf',
        mimeType: 'application/pdf',
      );

      final saved = File('${dir.path}/relatorio.pdf');
      expect(await saved.exists(), isTrue, reason: 'gravado direto na pasta');
      expect(await saved.readAsBytes(), bytes, reason: 'bytes íntegros');
      expect(stops, 1, reason: 'escopo liberado uma vez');
      expect(fileDownloadGalImageCount, 0);
      expect(fileDownloadGalVideoCount, 0);
    });
  });

  group('openBatchDownloadFolder (pasta única do lote)', skip: kIsWeb, () {
    final originalPicker = fileBatchFolderPicker;
    final originalStart = fileBatchFolderStartAccess;
    final originalStop = fileBatchFolderStopAccess;
    tearDown(() {
      fileBatchFolderPicker = originalPicker;
      fileBatchFolderStartAccess = originalStart;
      fileBatchFolderStopAccess = originalStop;
    });

    test('picker cancelado vira cancelled', () async {
      fileBatchFolderPicker = () async => null;

      final (:choice, :folder) = await openBatchDownloadFolder();
      expect(choice, BatchFolderOpen.cancelled);
      expect(folder, isNull);
    });

    test('escopo de acesso negado vira cancelled, sem folder', () async {
      fileBatchFolderPicker = () async => '/tmp/negada';
      fileBatchFolderStartAccess = (_) async => false;

      final (:choice, :folder) = await openBatchDownloadFolder();
      expect(choice, BatchFolderOpen.cancelled);
      expect(folder, isNull);
    });

    test('pasta aceita: escopo ativo, close libera UMA vez', () async {
      fileBatchFolderPicker = () async => '/tmp/pasta';
      var starts = 0;
      var stops = 0;
      fileBatchFolderStartAccess = (_) async {
        starts++;
        return true;
      };
      fileBatchFolderStopAccess = (_) async => stops++;

      final (:choice, :folder) = await openBatchDownloadFolder();
      expect(choice, BatchFolderOpen.folder);
      expect(folder!.path, '/tmp/pasta');
      expect(starts, 1, reason: 'escopo abre uma vez com a pasta');

      await folder.close();
      await folder.close(); // idempotente
      expect(stops, 1, reason: 'stop chamado uma vez só');
    });
  });
}
