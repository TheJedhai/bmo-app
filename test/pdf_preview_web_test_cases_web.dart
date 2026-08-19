// Blob URL lifecycle check for the PDF preview (chrome only).
//
// The iframe element itself is exercised manually (open/close/reopen a
// PDF in the vault); this covers the resource the leak test cares about:
// every createPdfPreview must be paired with exactly one revoke, and a
// second dispose must not revoke twice.
//
// Run: flutter test --platform=chrome test/pdf_preview_web_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/pdf_preview.dart';

void runPdfPreviewWebTests() {
  test('blob URL created and revoked exactly once', () async {
    pdfPreviewCreatedCount = 0;
    pdfPreviewDisposedCount = 0;

    final preview = await createPdfPreview(Uint8List.fromList([1, 2, 3]));
    expect(pdfPreviewCreatedCount, 1);
    expect(preview.isSystemPresented, isFalse,
        reason: 'web preview lives inside the viewer dialog');
    expect(await preview.present(), isTrue, reason: 'web present is a no-op');

    preview.dispose();
    expect(pdfPreviewDisposedCount, 1);

    preview.dispose();
    expect(pdfPreviewDisposedCount, 1,
        reason: 'second dispose is a no-op — blob revoked once');
  });
}
