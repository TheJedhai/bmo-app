// Temp-file leak check for the PDF preview (native/VM only).
//
// Runs on the host VM (macOS flutter_tester): the IoPdfPreview writes the
// decrypted bytes to Directory.systemTemp. Dispose must delete the file
// exactly once and stay safe when called again — the vault screen owns the
// handle (the Quick Look sheet is closed by the system) and may dispose it
// after a reopen that already disposed the previous one.
//
// Run: flutter test test/vault_pdf_preview_cleanup_test.dart
// Skipped on web (dart:io unavailable).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/pdf_preview.dart';

List<String> _tempPdfs() => Directory.systemTemp
    .listSync()
    .where((e) => e.path.contains('bmo_pdf_'))
    .map((e) => e.path)
    .toList();

void main() {
  test(
    'create/dispose leaves no temp file',
    skip: kIsWeb,
    () async {
      final before = _tempPdfs();
      pdfPreviewCreatedCount = 0;
      pdfPreviewDisposedCount = 0;

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final preview = await createPdfPreview(bytes);
      expect(pdfPreviewCreatedCount, 1);
      expect(preview.isSystemPresented, isTrue,
          reason: 'native preview is presented by the system (Quick Look)');
      expect(_tempPdfs().length, before.length + 1,
          reason: 'create writes exactly one temp file');

      preview.dispose();
      expect(pdfPreviewDisposedCount, 1);
      expect(_tempPdfs(), before, reason: 'dispose deleted the temp file');
    },
  );

  test(
    'dispose is idempotent',
    skip: kIsWeb,
    () async {
      final before = _tempPdfs();
      pdfPreviewCreatedCount = 0;
      pdfPreviewDisposedCount = 0;

      final preview =
          await createPdfPreview(Uint8List.fromList([1, 2, 3, 4]));
      preview.dispose();
      preview.dispose(); // must not throw or double-count

      expect(pdfPreviewDisposedCount, 1,
          reason: 'second dispose is a no-op');
      expect(_tempPdfs(), before,
          reason: 'no file left after repeated dispose');
    },
  );
}
