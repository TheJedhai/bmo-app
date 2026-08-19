export 'pdf_preview_stub.dart'
    if (dart.library.js_interop) 'pdf_preview_web.dart';

import 'package:flutter/widgets.dart';

/// Preview de PDF com recurso a liberar.
///
/// Ponte entre bytes decifrados e o visualizador de PDF da plataforma —
/// em ambas é DELEGAÇÃO, nunca renderização própria:
/// - web: iframe + visualizador embutido do browser (blob URL revogado no
///   [dispose]);
/// - nativo: arquivo temporário + folha do Quick Look (apagado no [dispose]).
///
/// pdfrx/pdfx rejeitados: empacotam PDFium (~4 MB no bundle web) para
/// renderizar em código próprio, o que o browser e o iOS já fazem.
///
/// ## Quem é dono do handle (e quando o recurso morre)
/// Web: o iframe vive DENTRO do dialog do viewer — o viewer cria, usa e
/// descarta no próprio dispose (blob revogado ao fechar, como sempre foi).
///
/// Nativo: quem fecha a folha do Quick Look é o SISTEMA — não há callback
/// de fechamento, então apagar "quando o preview fechar" não é confiável.
/// O handle é repassado pelo viewer a quem abriu (a tela do vault, via
/// `onPreviewOpened`) e morre só no dispose DA TELA — que roda depois do
/// fechamento do dialog, da folha e até do re-travamento do cofre.
///
/// Se o app for morto com a folha aberta, o dispose não roda: o arquivo
/// fica em NSTemporaryDirectory, que o iOS purga quando o app não está
/// rodando (a folha morre junto com o processo).
///
/// O call site nunca adivinha O QUE limpar — [dispose] faz a limpeza
/// inteira da plataforma e é seguro chamar mais de uma vez.
abstract class PdfPreview {
  /// True quando o preview é apresentado pelo sistema (Quick Look) e
  /// sobrevive ao fechamento do dialog. O viewer então repassa o handle
  /// (`onPreviewOpened`) em vez de descartá-lo no próprio dispose.
  bool get isSystemPresented;

  /// Apresenta o preview. Web: no-op. Nativo: folha do Quick Look.
  ///
  /// Retorna false quando o tipo não pode ser exibido — o caller mostra
  /// erro e o handle segue válido para retry.
  Future<bool> present();

  /// Conteúdo inline do dialog. Web: iframe com o visualizador do browser.
  /// Nativo: vazio (a apresentação é externa, via [present]).
  Widget buildContent();

  /// Libera o recurso (revoga o blob URL / apaga o temp). Seguro chamar
  /// mais de uma vez — a segunda chamada é no-op.
  void dispose();
}
