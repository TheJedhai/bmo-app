export 'file_stream_writer_stub.dart'
    if (dart.library.js_interop) 'file_stream_writer_web.dart';

import 'dart:typed_data';

/// Escrita em streaming de arquivo grande (download do cofre), sem
/// materializar tudo em memória.
///
/// Ciclo de vida explícito: [openFileStreamWriter] abre o destino ->
/// [writeChunk] N vezes -> [finalize] publica o arquivo completo. Em erro
/// ou cancelamento: [abort] descarta o parcial — SEMPRE seguro de chamar,
/// inclusive depois de [finalize] (no-op), para que o catch do call site
/// não precise saber até onde a gravação chegou.
///
/// Plataformas:
/// - Web: showSaveFilePicker + FileSystemWritableFileStream. O browser
///   grava num temporário e só renomeia para o destino no close() — abort
///   sem close() descarta o temporário e o destino nunca materializa.
/// - Nativo: File + RandomAccessFile em NSTemporaryDirectory (dart:io
///   puro). abort fecha o RAF e apaga o arquivo.
abstract class FileStreamWriter {
  /// Escreve um chunk decifrado na posição corrente — chamadas
  /// sequenciais anexam em ordem.
  Future<void> writeChunk(Uint8List bytes);

  /// Finaliza a gravação. Depois disto o arquivo é permanente e [abort]
  /// vira no-op.
  Future<void> finalize();

  /// Descarta a gravação. Seguro chamar sempre, mais de uma vez, inclusive
  /// depois de [finalize]. Nunca lança.
  Future<void> abort();
}

// `openFileStreamWriter` e `isFileStreamSaveAvailable` são definidas por
// cada branch do conditional export (web/stub), como `createVideoSource`
// em video_source.dart — declarar aqui roubaria a resolução do export.
//
// Assinatura única nas duas plataformas:
//
//   Future<FileStreamWriter?> openFileStreamWriter(
//     String suggestedName, {
//     String? destinationDirectory,
//   })
//
// [destinationDirectory] só age no nativo — grava o arquivo SOLTO nessa
// pasta com o nome [suggestedName] (seleção mista do cofre). Na web é
// ignorado: o diálogo de salvar decide o destino. Sem o parâmetro, o
// nativo continua gravando em NSTemporaryDirectory.
