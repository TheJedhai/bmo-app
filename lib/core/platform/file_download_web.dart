import 'dart:typed_data';

import 'file_download.dart';

/// Saves raw bytes to a file through the platform's save mechanism.
///
/// On web this triggers a browser download (Blob + anchor), for every
/// mime — gallery does not exist in the browser. The file name and
/// extension are preserved.
void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  saveWithFileSaver(bytes: bytes, fileName: fileName, mimeType: mimeType);
}
