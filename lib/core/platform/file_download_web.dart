import 'dart:typed_data';

import 'file_download.dart';
import 'file_stream_writer.dart';

/// Gate de tamanho da WEB — único lugar do projeto onde ele existe. No
/// nativo não há gate nenhum: a costura nativa decide só pelo mime.
const int _kLargeFileThreshold = 25 * 1024 * 1024; // 25 MiB

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

/// Web: arquivo pequeno vai por Blob (decryptAll), arquivo grande por
/// streaming com picker — e sem suporte no navegador, erro. O mime não
/// importa no browser.
SingleItemDownloadMode singleItemDownloadMode({
  required int originalSize,
  required String mimeType,
}) {
  if (originalSize >= _kLargeFileThreshold) {
    return isFileStreamSaveAvailable
        ? SingleItemDownloadMode.streamToPicker
        : SingleItemDownloadMode.unsupportedLarge;
  }
  return SingleItemDownloadMode.blob;
}

/// Web: não há galeria — inalcançável (só chamado no modo
/// streamToGallery, que a web nunca produz). Existe para a costura
/// compilar com assinatura única.
Future<String?> ensureGalleryAccess() async => null;

/// Web: idem — inalcançável, existe pela assinatura única.
Future<String?> deliverFileToGallery({
  required String filePath,
  required String fileName,
  required String mimeType,
}) async =>
    null;

/// Web: não há pasta única — getDirectoryPath é UnimplementedError no
/// browser. A seleção mista vira downloads individuais.
Future<({BatchFolderOpen choice, BatchDownloadFolder? folder})>
    openBatchDownloadFolder() async =>
        (choice: BatchFolderOpen.individualDownloads, folder: null);
