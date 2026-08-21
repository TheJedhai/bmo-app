// Mime routing + temp-file leak check for downloadBytes native branch
// (VM only).
//
// Runs on the host VM (macOS flutter_tester): gal has no plugin there, so
// the access check fails (generic path) or, with the seam set to true, the
// put itself fails — exactly the failure paths that must still delete the
// decrypted temp video.
//
// Run: flutter test test/file_download_stub_test.dart
// Skipped on web (dart:io unavailable).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/file_download_stub.dart';

List<String> _tempDownloads() => Directory.systemTemp
    .listSync()
    .where((e) => e.path.contains('bmo_download_'))
    .map((e) => e.path)
    .toList();

void main() {
  // Os caminhos de falha passam por MethodChannels (gal/file_saver sem
  // plugin no flutter_tester) — precisam do binding inicializado.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalAccessCheck = fileDownloadGalleryAccessCheck;
  tearDown(() {
    fileDownloadGalleryAccessCheck = originalAccessCheck;
  });

  test(
    'image mime routes to gal, access denied leaves no temp',
    skip: kIsWeb,
    () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadFileSaverCount = 0;
      fileDownloadTempCreatedCount = 0;
      fileDownloadTempDeletedCount = 0;
      final before = _tempDownloads();

      // Default seam: no gal plugin on the tester, access check fails.
      await downloadBytesNative(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'bmo-image-1.png',
        mimeType: 'image/png',
      );

      expect(fileDownloadGalImageCount, 1, reason: 'image routes to gal');
      expect(fileDownloadGalVideoCount, 0);
      expect(fileDownloadFileSaverCount, 0);
      expect(fileDownloadTempCreatedCount, 0,
          reason: 'no temp before access granted');
      expect(_tempDownloads(), before);
    },
  );

  test(
    'video mime routes to gal, put failure deletes the temp file',
    skip: kIsWeb,
    () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadFileSaverCount = 0;
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
    },
  );

  test(
    'video with access denied never writes temp',
    skip: kIsWeb,
    () async {
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
    },
  );

  test(
    'any other mime routes to file_saver',
    skip: kIsWeb,
    () async {
      fileDownloadGalImageCount = 0;
      fileDownloadGalVideoCount = 0;
      fileDownloadFileSaverCount = 0;

      // file_saver fails on the tester (no plugin), caught by catchError.
      await downloadBytesNative(
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        fileName: 'relatorio.pdf',
        mimeType: 'application/pdf',
      );

      expect(fileDownloadFileSaverCount, 1,
          reason: 'pdf routes to file_saver');
      expect(fileDownloadGalImageCount, 0);
      expect(fileDownloadGalVideoCount, 0);
    },
  );
}
