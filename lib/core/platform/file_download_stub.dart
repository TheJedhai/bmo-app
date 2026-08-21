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
/// Caminho legado de BYTES JÁ EM MEMÓRIA (imagens do chat e da galeria):
/// image/* e video/* vão para a galeria; qualquer outro mime grava na
/// pasta escolhida — file_saver saiu do nativo. O cofre não passa mais por
/// aqui: o download do cofre é sempre streaming
/// ([singleItemDownloadMode]).
Future<void> downloadBytesNative({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  if (mimeType.startsWith('image/')) {
    fileDownloadGalImageCount++;
    final accessError = await ensureGalleryAccess();
    if (accessError != null) {
      _showError(accessError);
      return;
    }
    try {
      await Gal.putImageBytes(bytes, name: _nameWithoutExtension(fileName));
    } on GalException catch (e) {
      _showError(_messageForGal(e));
    } catch (e) {
      debugPrint('Save to gallery failed: $e');
      _showError('Falha ao salvar na galeria.');
    }
  } else if (mimeType.startsWith('video/')) {
    fileDownloadGalVideoCount++;
    final accessError = await ensureGalleryAccess();
    if (accessError != null) {
      _showError(accessError);
      return;
    }
    // Bytes decifrados em disco: um único try/finally garante que todo
    // caminho de saída — sucesso, GalException, erro genérico — apaga o
    // temp antes de retornar.
    final file = File(_tempPath(fileName));
    try {
      await file.writeAsBytes(bytes, flush: true);
      fileDownloadTempCreatedCount++;
      await Gal.putVideo(file.path);
    } on GalException catch (e) {
      _showError(_messageForGal(e));
    } catch (e) {
      debugPrint('Save to gallery failed: $e');
      _showError('Falha ao salvar na galeria.');
    } finally {
      await _deleteQuietly(file);
    }
  } else {
    // Não-mídia: grava direto na pasta escolhida — mesmo mecanismo do
    // lote misto (picker + escopo de segurança + close em finally).
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
