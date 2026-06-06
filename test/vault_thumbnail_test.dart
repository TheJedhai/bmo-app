// ignore_for_file: avoid_web_libraries_in_flutter

// Unit tests for vault thumbnail generation.
//
// Tests:
// 1. generateThumbnail for valid images → returns JPEG bytes
// 2. generateThumbnail for PDF/unsupported → null
// 3. generateThumbnail for corrupted bytes → null (no crash)
// 4. generateThumbnail for video > 200 MiB → null
// 5. generateThumbnail for invalid video bytes → null (no crash)
// 6. _scaleDimensions — aspect ratio, degenerate, no-op cases
//
// Run: flutter test --platform=chrome test/vault_thumbnail_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/vault/data/vault_thumbnail.dart';

// ---------------------------------------------------------------------------
// Test data helpers
// ---------------------------------------------------------------------------

/// Creates a small valid JPEG by rendering a canvas and exporting.
Uint8List _createTestJpeg({int width = 8, int height = 6}) {
  final canvas = html.CanvasElement()
    ..width = width
    ..height = height;
  final ctx = canvas.context2D;
  ctx.fillStyle = '#4488cc';
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#ff6600';
  ctx.fillRect(1, 1, width - 2, height - 2);

  final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);
  final comma = dataUrl.indexOf(',');
  final base64Str = dataUrl.substring(comma + 1);
  return base64Decode(base64Str) as Uint8List;
}

/// Creates a small valid PNG by rendering a canvas and exporting.
Uint8List _createTestPng({int width = 8, int height = 6}) {
  final canvas = html.CanvasElement()
    ..width = width
    ..height = height;
  final ctx = canvas.context2D;
  ctx.fillStyle = '#44cc88';
  ctx.fillRect(0, 0, width, height);

  final dataUrl = canvas.toDataUrl('image/png');
  final comma = dataUrl.indexOf(',');
  final base64Str = dataUrl.substring(comma + 1);
  return base64Decode(base64Str) as Uint8List;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // generateThumbnail — image
  // =========================================================================
  group('generateThumbnail (image)', () {
    test('returns JPEG bytes for valid JPEG image', () async {
      final jpegBytes = _createTestJpeg();
      final thumb = await generateThumbnail(jpegBytes, 'image/jpeg');

      expect(thumb, isNotNull);
      expect(thumb!.length, greaterThan(0));
      // JPEG magic bytes
      expect(thumb[0], 0xFF);
      expect(thumb[1], 0xD8);
    });

    test('returns JPEG bytes for valid PNG image', () async {
      final pngBytes = _createTestPng();
      final thumb = await generateThumbnail(pngBytes, 'image/png');

      expect(thumb, isNotNull);
      expect(thumb!.length, greaterThan(0));
      // Should be re-encoded as JPEG
      expect(thumb[0], 0xFF);
      expect(thumb[1], 0xD8);
    });

    test('returns null for PDF MIME type', () async {
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
      final thumb = await generateThumbnail(pdfBytes, 'application/pdf');
      expect(thumb, isNull);
    });

    test('returns null for text/plain', () async {
      final textBytes = Uint8List.fromList('hello world'.codeUnits);
      final thumb = await generateThumbnail(textBytes, 'text/plain');
      expect(thumb, isNull);
    });

    test('returns null for application/octet-stream', () async {
      final bytes = Uint8List(100);
      final thumb =
          await generateThumbnail(bytes, 'application/octet-stream');
      expect(thumb, isNull);
    });

    test('returns null for corrupted image bytes', () async {
      final badBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0xFF]);
      final thumb = await generateThumbnail(badBytes, 'image/jpeg');
      expect(thumb, isNull);
    });

    test('thumbnail size is reasonable (<< 100 KB)', () async {
      final jpegBytes = _createTestJpeg();
      final thumb = await generateThumbnail(jpegBytes, 'image/jpeg');

      expect(thumb, isNotNull);
      // A 256px JPEG at quality 0.7 should be well under 100 KB.
      expect(thumb!.length, lessThan(100 * 1024));
    });
  });

  // =========================================================================
  // generateThumbnail — video
  // =========================================================================
  group('generateThumbnail (video)', () {
    test('returns null for video bytes over 200 MiB limit', () async {
      final largeBytes = Uint8List(kVideoThumbnailMaxBytes + 1);
      final thumb = await generateThumbnail(largeBytes, 'video/mp4');
      expect(thumb, isNull);
    });

    test('returns null for small but invalid video bytes', () async {
      // 100 bytes of garbage is not a valid video → should return null, not
      // crash.
      final badBytes = Uint8List.fromList(
        List.generate(100, (i) => i % 256),
      );
      final thumb = await generateThumbnail(badBytes, 'video/mp4');
      expect(thumb, isNull);
    });

    test('returns null for empty video bytes', () async {
      final empty = Uint8List(0);
      final thumb = await generateThumbnail(empty, 'video/mp4');
      expect(thumb, isNull);
    });
  });

  // =========================================================================
  // _scaleDimensions
  // =========================================================================
  group('_scaleDimensions', () {
    // We access the private helper via the public API indirectly but can
    // also test the dimension logic through the thumbnail output.

    test('landscape image is scaled to fit max dimension', () async {
      // Create a wide image by drawing on a canvas.
      final canvas = html.CanvasElement()
        ..width = 800
        ..height = 400;
      final ctx = canvas.context2D;
      ctx.fillStyle = '#ff0000';
      ctx.fillRect(0, 0, 800, 400);

      final dataUrl = canvas.toDataUrl('image/png');
      final comma = dataUrl.indexOf(',');
      final base64Str = dataUrl.substring(comma + 1);
      final pngBytes = base64Decode(base64Str) as Uint8List;

      final thumb = await generateThumbnail(pngBytes, 'image/png');
      expect(thumb, isNotNull);
      expect(thumb![0], 0xFF);
      expect(thumb[1], 0xD8);

      // Decode the JPEG to check dimensions.
      final checkImage = html.ImageElement();
      final checkBlob = html.Blob([thumb]);
      final checkUrl = html.Url.createObjectUrl(checkBlob);
      try {
        final completer = Completer<void>();
        checkImage.onLoad.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        checkImage.src = checkUrl;
        await completer.future.timeout(const Duration(seconds: 5));

        // Aspect ratio: 800:400 = 2:1, max dim 256 → 256×128
        expect(checkImage.naturalWidth, 256);
        expect(checkImage.naturalHeight, 128);
      } finally {
        html.Url.revokeObjectUrl(checkUrl);
      }
    });

    test('portrait image is scaled to fit max dimension', () async {
      final canvas = html.CanvasElement()
        ..width = 200
        ..height = 600;
      final ctx = canvas.context2D;
      ctx.fillStyle = '#00ff00';
      ctx.fillRect(0, 0, 200, 600);

      final dataUrl = canvas.toDataUrl('image/png');
      final comma = dataUrl.indexOf(',');
      final base64Str = dataUrl.substring(comma + 1);
      final pngBytes = base64Decode(base64Str) as Uint8List;

      final thumb = await generateThumbnail(pngBytes, 'image/png');
      expect(thumb, isNotNull);

      final checkImage = html.ImageElement();
      final checkBlob = html.Blob([thumb!]);
      final checkUrl = html.Url.createObjectUrl(checkBlob);
      try {
        final completer = Completer<void>();
        checkImage.onLoad.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        checkImage.src = checkUrl;
        await completer.future.timeout(const Duration(seconds: 5));

        // Aspect ratio: 200:600 = 1:3, max dim 256 → 85×256
        expect(checkImage.naturalHeight, 256);
        expect(checkImage.naturalWidth, lessThan(256));
      } finally {
        html.Url.revokeObjectUrl(checkUrl);
      }
    });

    test('small image is NOT upscaled', () async {
      // A 50×50 image should stay 50×50 (not be upscaled to 256).
      final canvas = html.CanvasElement()
        ..width = 50
        ..height = 50;
      final ctx = canvas.context2D;
      ctx.fillStyle = '#0000ff';
      ctx.fillRect(0, 0, 50, 50);

      final dataUrl = canvas.toDataUrl('image/png');
      final comma = dataUrl.indexOf(',');
      final base64Str = dataUrl.substring(comma + 1);
      final pngBytes = base64Decode(base64Str) as Uint8List;

      final thumb = await generateThumbnail(pngBytes, 'image/png');
      expect(thumb, isNotNull);

      final checkImage = html.ImageElement();
      final checkBlob = html.Blob([thumb!]);
      final checkUrl = html.Url.createObjectUrl(checkBlob);
      try {
        final completer = Completer<void>();
        checkImage.onLoad.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        checkImage.src = checkUrl;
        await completer.future.timeout(const Duration(seconds: 5));

        // Should stay 50×50 (not upscaled).
        expect(checkImage.naturalWidth, 50);
        expect(checkImage.naturalHeight, 50);
      } finally {
        html.Url.revokeObjectUrl(checkUrl);
      }
    });

    test('square large image is scaled correctly', () async {
      final canvas = html.CanvasElement()
        ..width = 512
        ..height = 512;
      final ctx = canvas.context2D;
      ctx.fillStyle = '#ffff00';
      ctx.fillRect(0, 0, 512, 512);

      final dataUrl = canvas.toDataUrl('image/png');
      final comma = dataUrl.indexOf(',');
      final base64Str = dataUrl.substring(comma + 1);
      final pngBytes = base64Decode(base64Str) as Uint8List;

      final thumb = await generateThumbnail(pngBytes, 'image/png');
      expect(thumb, isNotNull);

      final checkImage = html.ImageElement();
      final checkBlob = html.Blob([thumb!]);
      final checkUrl = html.Url.createObjectUrl(checkBlob);
      try {
        final completer = Completer<void>();
        checkImage.onLoad.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });
        checkImage.src = checkUrl;
        await completer.future.timeout(const Duration(seconds: 5));

        // 512×512 → 256×256
        expect(checkImage.naturalWidth, 256);
        expect(checkImage.naturalHeight, 256);
      } finally {
        html.Url.revokeObjectUrl(checkUrl);
      }
    });
  });
}
