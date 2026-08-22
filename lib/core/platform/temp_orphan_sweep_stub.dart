import 'dart:io';

/// Prefixos dos temporários que os caminhos de bytes decifrados do BMO usam
/// (ver video_source_stub, pdf_preview_stub, file_download_stub e
/// file_stream_writer_stub). O final que importa é o NSTemporaryDirectory
/// do iOS — [Directory.systemTemp] —, então o match pelo NOME do arquivo é
/// suficiente para não tocar em nada que o BMO não tenha criado.
const List<String> _bmoTempPrefixes = [
  'bmo_video_',
  'bmo_pdf_',
  'bmo_download_',
];

/// Varre [Directory.systemTemp] e apaga os temporários órfãos do BMO.
///
/// Por que existe: os caminhos `bmo_*` escrevem bytes DECIFRADOS em arquivo
/// temporário e apagam em finally/dispose — que cobrem o caso normal. Esta
/// varredura cobre a MORTE do processo (crash, force-quit, Jetsam), quando o
/// arquivo fica no NSTemporaryDirectory até o iOS purgar. Roda uma vez no
/// boot, fire-and-forget, e é melhor esforço: falha não pode quebrar o app.
///
/// Web não chega aqui — lá não há temp em disco (no-op em _web).
Future<void> sweepOrphanTempFiles() async {
  try {
    final List<File> matches = <File>[];
    await for (final entity in Directory.systemTemp.list()) {
      if (entity is! File) continue;
      // Só o nome do arquivo casa com os prefixos; nunca varre o dir inteiro.
      final String name = entity.uri.pathSegments.last;
      if (_bmoTempPrefixes.any(name.startsWith)) matches.add(entity);
    }
    for (final File file in matches) {
      try {
        await file.delete();
      } catch (_) {
        // Melhor esforço: arquivo em uso (ex.: AVPlayer lendo) — o SO purga.
      }
    }
  } catch (_) {
    // Melhor esforço: varredura nunca pode quebrar o boot.
  }
}
