export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Chave global do ScaffoldMessenger — o download roda fora de contexto
/// (helper fire-and-forget) e o erro de salvar precisa aparecer para o
/// usuário. Montada no MaterialApp (app.dart). Em testes, sem MaterialApp,
/// `currentState` é null e o aviso é simplesmente descartado.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Salva via file_saver — comportamento web e fallback nativo (mime fora
/// de image/video): no navegador vira Blob + anchor; no iOS abre o picker
/// "Salvar em Arquivos". Fire-and-forget com log de falha.
void saveWithFileSaver({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final (:extension, :mime) = mimeToSaver(mimeType, fileName);
  // file_saver appends the extension to `name`, so strip it here when the
  // incoming file name already carries it.
  final name = stripFileExtension(fileName, extension);

  FileSaver.instance
      .saveAs(
        name: name,
        bytes: bytes,
        fileExtension: extension,
        mimeType: mime,
        customMimeType: mime == MimeType.custom ? mimeType : null,
      )
      .catchError((Object error) {
        debugPrint('Save failed: $error');
        return null;
      });
}

/// Removes a trailing ".$extension" from [fileName] when it matches
/// exactly (case-insensitive). Returns [fileName] unchanged otherwise.
String stripFileExtension(String fileName, String extension) {
  final suffix = '.$extension';
  if (fileName.length <= suffix.length) return fileName;
  final tail = fileName.substring(fileName.length - suffix.length);
  if (tail.toLowerCase() != suffix.toLowerCase()) return fileName;
  return fileName.substring(0, fileName.length - suffix.length);
}

({String extension, MimeType mime}) mimeToSaver(
  String mimeType,
  String fileName,
) {
  switch (mimeType) {
    case 'image/png':
      return (extension: 'png', mime: MimeType.png);
    case 'image/jpeg':
      return (extension: 'jpg', mime: MimeType.jpeg);
    case 'image/webp':
      return (extension: 'webp', mime: MimeType.webp);
    case 'image/gif':
      return (extension: 'gif', mime: MimeType.gif);
    case 'image/svg+xml':
      return (extension: 'svg', mime: MimeType.svg);
    default:
      // Unmapped mime: fall back to the extension already present in the
      // file name, and pass the mime through as a custom type.
      final dot = fileName.lastIndexOf('.');
      final extension = dot > 0 && dot < fileName.length - 1
          ? fileName.substring(dot + 1)
          : 'bin';
      return (extension: extension, mime: MimeType.custom);
  }
}

/// Pasta única para salvar a seleção mista ("qualquer outra composição").
///
/// Nativo (iOS): o picker de diretório foi aberto UMA vez e o escopo de
/// segurança fica ativo até [close] — gravar na pasta sem
/// startAccessingSecurityScopedResource falha com EPERM, e o escopo não
/// liberado vaza recurso do kernel (o app pode perder a capacidade de
/// adicionar locais ao sandbox até reiniciar). [close] é obrigatório em
/// todo caminho de saída — try/finally no call site.
///
/// Web: a plataforma não tem pasta única — a costura vira downloads
/// individuais (ver [BatchFolderOpen]).
abstract class BatchDownloadFolder {
  /// Pasta onde os arquivos são gravados soltos (com os nomes originais).
  String get path;

  /// Libera o escopo de segurança. Seguro chamar mais de uma vez.
  Future<void> close();
}

/// Desfecho da abertura da pasta do lote.
enum BatchFolderOpen {
  /// Nativo: pasta escolhida, escopo ativo — gravar os arquivos nela.
  folder,

  /// Web: sem pasta única — a seleção vira downloads individuais.
  individualDownloads,

  /// Nativo: usuário cancelou o picker (ou o escopo foi negado) — abortar.
  cancelled,
}
