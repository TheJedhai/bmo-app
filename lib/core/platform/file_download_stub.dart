import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'file_download.dart';
import 'file_stream_writer.dart';

/// Contadores de roteamento/limpeza — testes de mime routing e de
/// vazamento de arquivo temporário.
int fileDownloadGalImageCount = 0;
int fileDownloadGalVideoCount = 0;
int fileDownloadTempCreatedCount = 0;
int fileDownloadTempDeletedCount = 0;

/// Seam de teste: o flutter_tester não tem plugin do gal, então a checagem
/// de acesso falha e o put nunca roda. Trocar por `() async => true` faz o
/// fluxo chegar no put — que então falha — e exercita a limpeza do temp.
@visibleForTesting
Future<bool> Function() fileDownloadGalleryAccessCheck = _galleryAccessImpl;

Future<bool> _galleryAccessImpl() async {
  if (await Gal.hasAccess()) return true;
  return await Gal.requestAccess();
}

/// Assinatura pública única nas duas plataformas — ver file_download.dart.
/// Fire-and-forget: falha é reportada via snackbar, nunca lançada ao caller.
///
/// Caminho de BYTES JÁ EM MÃO (imagem gerada do chat, galeria). Roteia pela
/// MESMA decisão do cofre ([singleItemDownloadMode], mime decide) e entrega
/// com os mesmos helpers (putImageBytes/putVideo + pasta escolhida). Para
/// arquivo em disco (item grande), use o fluxo do cofre em vault_screen.
void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  unawaited(
    downloadBytesNative(bytes: bytes, fileName: fileName, mimeType: mimeType),
  );
}

/// Worker nativo — Future para os testes poderem aguardar o desfecho.
///
/// Roteia por [singleItemDownloadMode] — a decisão de PARA ONDE VAI existe
/// num lugar só no projeto. A diferença para o cofre é só a PRIMITIVA de
/// entrega: aqui os bytes já estão em memória (imagem vai por putImageBytes
/// sem tocar disco; vídeo escreve um temp e entrega por path), enquanto o
/// cofre streama o arquivo grande e usa putImage(path).
Future<void> downloadBytesNative({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final mode = singleItemDownloadMode(
    originalSize: bytes.length,
    mimeType: mimeType,
  );
  switch (mode) {
    case SingleItemDownloadMode.streamToGallery:
      await _deliverMediaBytes(bytes, fileName, mimeType);
      break;
    case SingleItemDownloadMode.streamToFolder:
      await _deliverBytesToFolder(bytes, fileName);
      break;
    case SingleItemDownloadMode.blob:
    case SingleItemDownloadMode.streamToPicker:
    case SingleItemDownloadMode.unsupportedLarge:
      // Nativo com bytes nunca chega aqui: singleItemDownloadMode nativo
      // decide só pelo mime (mídia -> galeria, senão pasta).
      break;
  }
}

/// Entrega mídia (image/*|video/*) com bytes em mão. Acesso à galeria é
/// checado aqui, uma vez, para imagem e vídeo.
Future<void> _deliverMediaBytes(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final accessError = await ensureGalleryAccess();
  if (accessError != null) {
    _showError(accessError);
    return;
  }
  if (mimeType.startsWith('image/')) {
    // Imagem: bytes já em memória, putImageBytes sem escrever temp.
    final err = await _deliverImageBytesToGallery(
      bytes: bytes,
      fileName: fileName,
    );
    if (err != null) _showError(err);
  } else {
    // Vídeo: a galeria pede um path — grava o temp e entrega pela MESMA via
    // do cofre ([deliverFileToGallery] apaga em finally, inclusive em erro).
    final file = File(_tempPath(fileName));
    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('Temp write failed: $e');
      await _deleteQuietly(file);
      _showError('Falha ao salvar na galeria.');
      return;
    }
    final err = await deliverFileToGallery(
      filePath: file.path,
      fileName: fileName,
      mimeType: mimeType,
    );
    if (err != null) _showError(err);
  }
}

/// Não-mídia com bytes: grava direto na pasta escolhida — mesmo mecanismo
/// do cofre (picker + escopo de segurança + close em finally).
Future<void> _deliverBytesToFolder(Uint8List bytes, String fileName) async {
  final open = await openBatchDownloadFolder();
  if (open.choice != BatchFolderOpen.folder) return; // cancelado
  try {
    final writer = await openFileStreamWriter(
      fileName,
      destinationDirectory: open.folder!.path,
    );
    if (writer == null) {
      _showError('Não foi possível criar o arquivo na pasta escolhida '
          '(já existe?).');
      return;
    }
    try {
      await writer.writeChunk(bytes);
      await writer.finalize();
    } catch (e) {
      await writer.abort();
      debugPrint('Save to folder failed: $e');
      _showError('Falha ao salvar na pasta escolhida.');
    }
  } finally {
    await open.folder!.close();
  }
}

/// Entrega bytes de imagem à galeria via putImageBytes — sem temp (o byte já
/// está em memória). Retorna mensagem de erro ou null em sucesso; quem
/// mostra é o caller. Mesma forma de [deliverFileToGallery].
Future<String?> _deliverImageBytesToGallery({
  required Uint8List bytes,
  required String fileName,
}) async {
  fileDownloadGalImageCount++;
  try {
    await Gal.putImageBytes(bytes, name: _nameWithoutExtension(fileName));
    return null;
  } on GalException catch (e) {
    return _messageForGal(e);
  } catch (e) {
    debugPrint('Save to gallery failed: $e');
    return 'Falha ao salvar na galeria.';
  }
}

/// Nativo: o mime decide SOZINHO — nenhum gate de tamanho, em ramo
/// nenhum. Mídia de qualquer tamanho streama para temp e vai à galeria
/// (trade-off aceito: imagem pequena toca o disco em claro por um
/// instante; o temp é apagado em finally). Não-mídia de qualquer tamanho
/// grava em streaming direto na pasta escolhida (trade-off aceito: sem
/// renomeação no diálogo — sai com o nome real do item do cofre; renomear
/// dentro do cofre está no roadmap).
SingleItemDownloadMode singleItemDownloadMode({
  required int originalSize,
  required String mimeType,
}) {
  final isMedia =
      mimeType.startsWith('image/') || mimeType.startsWith('video/');
  return isMedia
      ? SingleItemDownloadMode.streamToGallery
      : SingleItemDownloadMode.streamToFolder;
}

/// Garante acesso à galeria ANTES do streaming — sem acesso, o download
/// inteiro iria para o lixo no final. Retorna mensagem de erro ou null em
/// sucesso; quem mostra é o caller.
Future<String?> ensureGalleryAccess() async {
  try {
    if (await fileDownloadGalleryAccessCheck()) return null;
    return 'Acesso à galeria negado. Permita salvar fotos e vídeos nas '
        'Configurações do iPhone.';
  } on GalException catch (e) {
    return _messageForGal(e);
  } catch (e) {
    debugPrint('Gallery access check failed: $e');
    return 'Falha ao acessar a galeria.';
  }
}

/// Entrega o arquivo finalizado (streaming em temp) à galeria via
/// putImage/putVideo e apaga o temp em finally — inclusive em erro do
/// Gal. Retorna mensagem de erro ou null em sucesso; quem mostra é o
/// caller (a UI espera esta confirmação antes de limpar o progresso).
Future<String?> deliverFileToGallery({
  required String filePath,
  required String fileName,
  required String mimeType,
}) async {
  fileDownloadTempCreatedCount++;
  try {
    if (mimeType.startsWith('video/')) {
      fileDownloadGalVideoCount++;
      await Gal.putVideo(filePath);
    } else {
      fileDownloadGalImageCount++;
      await Gal.putImage(filePath);
    }
    return null;
  } on GalException catch (e) {
    return _messageForGal(e);
  } catch (e) {
    debugPrint('Save to gallery failed: $e');
    return 'Falha ao salvar na galeria.';
  } finally {
    await _deleteQuietly(File(filePath));
  }
}

String _messageForGal(GalException e) {
  switch (e.type) {
    case GalExceptionType.accessDenied:
      return 'Acesso à galeria negado. Permita salvar fotos e vídeos nas '
          'Configurações do iPhone.';
    case GalExceptionType.notEnoughSpace:
      return 'Sem espaço suficiente no dispositivo para salvar.';
    case GalExceptionType.notSupportedFormat:
      return 'Formato não suportado pela galeria.';
    case GalExceptionType.unexpected:
      return 'Falha ao salvar na galeria.';
  }
}

void _showError(String message) {
  debugPrint('Download failed: $message');
  appScaffoldMessengerKey.currentState
      ?.showSnackBar(SnackBar(content: Text(message)));
}

/// dart:io puro — [Directory.systemTemp] já é o NSTemporaryDirectory do
/// iOS, que o SO também purga se o app morrer antes da limpeza. Extensão
/// vem do próprio nome do arquivo; a galeria infere o formato do conteúdo.
String _tempPath(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final ext = dot > 0 && dot < fileName.length - 1
      ? fileName.substring(dot)
      : '.tmp';
  return '${Directory.systemTemp.path}/bmo_download_'
      '${DateTime.now().microsecondsSinceEpoch}'
      '_${Random().nextInt(1 << 32)}$ext';
}

/// O gal pede o `name` da imagem SEM extensão (originalFilename no iOS).
String _nameWithoutExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}

/// Apaga sem reclamar — falha de limpeza não pode quebrar o download.
Future<void> _deleteQuietly(File file) async {
  fileDownloadTempDeletedCount++;
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Melhor esforço: NSTemporaryDirectory é purgado pelo SO.
  }
}

// ----------------------------------------------------------
// Pasta única do lote (seleção mista)
// ----------------------------------------------------------

/// Seams de teste — mesmo padrão de [fileDownloadGalleryAccessCheck]:
/// o flutter_tester não tem plugin do file_picker nem a camada nativa do
/// canal de escopo de segurança.
@visibleForTesting
Future<String?> Function() fileBatchFolderPicker = _pickFolder;
@visibleForTesting
Future<bool> Function(String path) fileBatchFolderStartAccess =
    _startFolderAccess;
@visibleForTesting
Future<void> Function(String path) fileBatchFolderStopAccess =
    _stopFolderAccess;

/// Channel registrado no AppDelegate (Runner). O file_picker 8.3.7 NÃO
/// faz startAccessingSecurityScopedResource na URL devolvida pelo
/// UIDocumentPicker — sem o escopo, gravar na pasta fora do sandbox do app
/// falha com EPERM; sem o stop, o app vaza recurso do kernel.
const MethodChannel _securityScopedChannel =
    MethodChannel('bmo/security_scoped');

Future<String?> _pickFolder() => FilePicker.platform.getDirectoryPath();

Future<bool> _startFolderAccess(String path) async {
  try {
    return await _securityScopedChannel
            .invokeMethod<bool>('startAccessing', path) ??
        false;
  } on MissingPluginException {
    // Sem a camada nativa (flutter_tester/desktop): filesystem aberto,
    // sem sandbox — acesso direto.
    return true;
  }
}

Future<void> _stopFolderAccess(String path) async {
  try {
    await _securityScopedChannel.invokeMethod<void>('stopAccessing', path);
  } on MissingPluginException {
    // Sem a camada nativa: nada a liberar.
  }
}

/// Abre a pasta única do lote — picker UMA vez, escopo ativo até o
/// [BatchDownloadFolder.close] (obrigatório em finally no call site).
Future<({BatchFolderOpen choice, BatchDownloadFolder? folder})>
    openBatchDownloadFolder() async {
  final path = await fileBatchFolderPicker();
  if (path == null) {
    return (choice: BatchFolderOpen.cancelled, folder: null);
  }
  if (!await fileBatchFolderStartAccess(path)) {
    _showError('Não foi possível acessar a pasta escolhida.');
    return (choice: BatchFolderOpen.cancelled, folder: null);
  }
  return (
    choice: BatchFolderOpen.folder,
    folder: _NativeBatchDownloadFolder(path),
  );
}

class _NativeBatchDownloadFolder implements BatchDownloadFolder {
  _NativeBatchDownloadFolder(this.path);

  @override
  final String path;

  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await fileBatchFolderStopAccess(path);
  }
}
