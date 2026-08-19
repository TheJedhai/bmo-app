import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:quick_look/quick_look.dart';

import 'pdf_preview.dart';

/// Contadores de create/dispose — testes de vazamento de arquivo temporário.
int pdfPreviewCreatedCount = 0;
int pdfPreviewDisposedCount = 0;

/// Preview nativo (iOS): grava os bytes decifrados em arquivo temporário,
/// apresenta a folha do Quick Look e apaga no [dispose].
///
/// dart:io puro — path_provider é desnecessário, [Directory.systemTemp] já
/// é o NSTemporaryDirectory do iOS, que o SO também purga se o app morrer
/// antes do dispose.
///
/// Quem fecha a folha é o sistema: o [dispose] NÃO é amarrado ao
/// fechamento do Quick Look, e sim ao ciclo de vida da tela do vault que
/// abriu o preview (o viewer repassa o handle via `onPreviewOpened` — ver
/// pdf_preview.dart).
class IoPdfPreview implements PdfPreview {
  IoPdfPreview._(this._file);

  final File _file;
  bool _disposed = false;

  static Future<IoPdfPreview> create(Uint8List bytes) async {
    // Extensão fixa: só application/pdf chega aqui (router filtra o MIME).
    final file = File(
      '${Directory.systemTemp.path}/bmo_pdf_'
      '${DateTime.now().microsecondsSinceEpoch}'
      '_${Random().nextInt(1 << 32)}.pdf',
    );
    try {
      // flush: true — dados em disco antes do write retornar.
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Erro no meio da gravação: apagar o parcial antes de propagar.
      await _deleteQuietly(file);
      rethrow;
    }
    pdfPreviewCreatedCount++;
    return IoPdfPreview._(file);
  }

  @override
  bool get isSystemPresented => true;

  @override
  Future<bool> present() async {
    if (_disposed) return false;
    if (!await QuickLook.canOpenURL(_file.path)) return false;
    // openURL só completa quando a folha FECHA — não dá para esperar o
    // resultado sem travar a entrega do handle à tela. canOpenURL já
    // validou o arquivo; falha de apresentação é rara e fica em log.
    unawaited(QuickLook.openURL(_file.path).then(
      (_) {},
      onError: (Object e, StackTrace s) => debugPrint('QuickLook: $e'),
    ));
    return true;
  }

  @override
  Widget buildContent() => const SizedBox.shrink();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    pdfPreviewDisposedCount++;
    // Delete síncrono: unlink é operação de metadados, não lê o conteúdo —
    // e o arquivo some de fato quando o dispose retorna. Nesse ponto o
    // Quick Look já carregou o preview para o próprio processo (a folha
    // fecha antes da tela morrer em quase todos os caminhos); se falhar,
    // o NSTemporaryDirectory é purgado pelo SO.
    try {
      if (_file.existsSync()) _file.deleteSync();
    } catch (_) {
      // Melhor esforço: NSTemporaryDirectory é purgado pelo SO.
    }
  }
}

/// Apaga sem reclamar — falha de limpeza não pode quebrar o fechamento.
Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Melhor esforço: NSTemporaryDirectory é purgado pelo SO.
  }
}

Future<PdfPreview> createPdfPreview(Uint8List bytes) =>
    IoPdfPreview.create(bytes);
