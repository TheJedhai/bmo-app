// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'file_stream_writer.dart';

/// Whether the browser supports `window.showSaveFilePicker`.
///
/// Chrome 86+, Edge 86+, Opera 72+. Safari and Firefox do NOT support this
/// as of June 2026.
bool get isFileStreamSaveAvailable {
  try {
    final win = globalContext['window']! as JSObject;
    return win.has('showSaveFilePicker');
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// JS interop for window.showSaveFilePicker (typed, mirrors vault_cipher.dart)
// ---------------------------------------------------------------------------

@JS('window.showSaveFilePicker')
external JSPromise<JSObject> _showSaveFilePicker(JSObject options);

// ---------------------------------------------------------------------------
// File System Access API wrapper
// ---------------------------------------------------------------------------

/// Web: FileSystemWritableFileStream (File System Access API).
///
/// O browser grava em arquivo temporário e renomeia para o destino só no
/// `close()`. Por isso o abort SEM close(): [abort] descarta o temporário
/// e o destino nunca materializa — um parcial não pode ser apagado depois,
/// o handle é do usuário e o browser não garante delete.
class WebFileStreamWriter implements FileStreamWriter {
  WebFileStreamWriter._(this._stream);

  final JSObject _stream;
  bool _finalized = false;

  @override
  String? get filePath => null; // o destino é do browser, sem path.

  /// Plaintext chunk goes straight to the browser's disk buffer via
  /// JSUint8Array (BufferSource) — nothing accumulates in Dart memory.
  /// Sequential calls append in order (the write cursor advances).
  @override
  Future<void> writeChunk(Uint8List bytes) async {
    final writePromise = _stream.callMethod('write'.toJS, bytes.toJS);
    await (writePromise! as JSPromise<JSAny?>).toDart;
  }

  /// close() materializa o arquivo no destino.
  @override
  Future<void> finalize() async {
    final closePromise = _stream.callMethod('close'.toJS);
    await (closePromise! as JSPromise<JSAny?>).toDart;
    _finalized = true;
  }

  /// Aborta o writable stream SEM chamar close(): o temporário é
  /// descartado pelo browser e nada aparece no destino. Seguro sempre —
  /// depois de [finalize] é no-op; abort repetido e abort em stream já
  /// fechado/errado são engolidos.
  @override
  Future<void> abort() async {
    if (_finalized) return;
    try {
      final abortPromise = _stream.callMethod('abort'.toJS);
      await (abortPromise! as JSPromise<JSAny?>).toDart;
    } catch (_) {
      // Melhor esforço — o browser descarta o temporário de qualquer forma.
    }
  }
}

/// Abre o diálogo de destino e o writable stream. `null` = usuário
/// cancelou o diálogo (AbortError) ou API indisponível.
/// [destinationDirectory] é ignorado na web — o diálogo decide o destino.
Future<FileStreamWriter?> openFileStreamWriter(
  String suggestedName, {
  String? destinationDirectory,
}) async {
  final options = JSObject();
  options['suggestedName'] = suggestedName.toJS;

  try {
    final handle = await _showSaveFilePicker(options).toDart;

    final streamPromise = handle.callMethod('createWritable'.toJS);
    final stream =
        await (streamPromise! as JSPromise<JSAny?>).toDart as JSObject;

    return WebFileStreamWriter._(stream);
  } catch (_) {
    // User cancelled the dialog (AbortError) or API not available
    return null;
  }
}
