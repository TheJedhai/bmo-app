// Temp-file leak check for the video thumbnail pipeline (native/VM only).
//
// Runs on the host VM (macOS flutter_tester): the IoVideoSource writes the
// decrypted bytes to Directory.systemTemp. Every failed thumbnail attempt
// must still dispose its source and leave no bmo_video_* file behind.
//
// Run: flutter test test/vault_video_source_cleanup_test.dart
// Skipped on web (dart:io unavailable).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/video_source.dart';
import 'package:bmo_app/features/vault/data/vault_thumbnail.dart';

List<String> _tempVideos() => Directory.systemTemp
    .listSync()
    .where((e) => e.path.contains('bmo_video_'))
    .map((e) => e.path)
    .toList();

void main() {
  test(
    'no temp file left after failed video thumbnail attempt',
    skip: kIsWeb,
    () async {
      final before = _tempVideos();
      videoSourceCreatedCount = 0;
      videoSourceDisposedCount = 0;

      // Invalid video bytes: the thumbnail fails, the source is created and
      // disposed on the way out.
      final badBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final thumb = await generateThumbnail(badBytes, 'video/mp4');
      expect(thumb, isNull);

      expect(videoSourceCreatedCount, 1,
          reason: 'one source created for the attempt');
      expect(videoSourceDisposedCount, 1,
          reason: 'dispose runs in finally, even on failure');
      expect(_tempVideos(), before,
          reason: 'dispose deleted the temp file');
    },
  );

  test(
    'direct create/dispose leaves no temp file',
    skip: kIsWeb,
    () async {
      final before = _tempVideos();
      videoSourceCreatedCount = 0;
      videoSourceDisposedCount = 0;

      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final source = await createVideoSource(bytes, 'video/mp4');
      expect(videoSourceCreatedCount, 1);
      expect(_tempVideos().length, before.length + 1,
          reason: 'create writes exactly one temp file');

      source.dispose();
      expect(videoSourceDisposedCount, 1);
      expect(_tempVideos(), before,
          reason: 'dispose deleted the temp file');
    },
  );
}
