export 'file_range_reader_stub.dart'
    if (dart.library.js_interop) 'file_range_reader_web.dart';

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

/// Lê faixas `[start, end)` de um [XFile] para upload chunked, um buffer por
/// chamada, sem materializar o arquivo inteiro.
///
/// O call site abre UM reader uma vez e lê N faixas dele — é o que elimina o
/// custo por-chunk do `XFile.openRead`. Na web o [XFile] é um blob URL e a
/// cross_file re-hidrata o blob via XHR a CADA `openRead` (issue #91867),
/// materializando o arquivo todo de novo a cada chunk. Aqui o blob é obtido
/// UMA vez (handle, não bytes) e cada [readRange] fatia via `Blob.slice`.
///
/// O call site nunca adivinha O QUE limpar — [dispose] faz a limpeza.
abstract class FileRangeReader {
  /// Lê `[start]..[end)` em um buffer. `end` é exclusivo. Um buffer por
  /// chamada — o maior pico é um chunk, não o arquivo.
  Future<Uint8List> readRange(int start, int end);

  /// Libera o recurso. Seguro chamar mais de uma vez. No-op nesta costura:
  /// não criamos blob URL próprio (o [XFile] já o detém), então não há o que
  /// revogar. Existe para o call site fechar sem branch de plataforma.
  void dispose();
}
