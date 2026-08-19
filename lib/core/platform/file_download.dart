import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Shares raw bytes as a file through the platform share mechanism.
///
/// On web this opens the native share sheet when the browser supports it
/// (mobile browsers) and falls back to a direct file download on desktop
/// browsers. The file name is preserved in both paths.
void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  SharePlus.instance
      .share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        ),
      )
      .catchError((Object error) {
        debugPrint('Download/share failed: $error');
        return ShareResult.unavailable;
      });
}
