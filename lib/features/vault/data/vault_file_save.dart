/// Web-specific: File System Access API for streaming download.
///
/// Uses the browser's File System Access API (Chrome 86+, Edge 86+, Opera 72+)
/// to stream decrypted chunks directly to disk without holding the entire file
/// in memory. This avoids the double-memory problem of decryptAll + Blob URL.
///
/// ## Platform support
/// - **Chrome / Brave / Edge (desktop)**: fully supported
/// - **Safari / Firefox**: NOT supported as of June 2026
/// - **Android nativo** (future): precisará de implementação própria via
///   dart:io (File + RandomAccessFile para escrita sequencial), chamando
///   fetchChunkRange da mesma forma. A interface de chunks decifrados é
///   a mesma — só a saída (FileSystemWritableFileStream vs RandomAccessFile)
///   muda. **Ponto de troca**: substituir [openSaveStream], [writeChunk],
///   [closeStream] por equivalentes dart:io quando compilar para Android.
///
/// ## Security
/// - Conteúdo decifrado existe apenas no chunk atual sendo escrito
/// - NADA de DEK, KEK, plaintext, ou nome do arquivo em log/storage
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Detection
// ---------------------------------------------------------------------------

/// Whether the browser supports `window.showSaveFilePicker`.
///
/// Chrome 86+, Edge 86+, Opera 72+. Safari and Firefox do NOT support this
/// as of June 2026.
bool get isFileSystemAccessApiAvailable {
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
// File System Access API wrapper  (PONTO DE TROCA para Android nativo)
// ---------------------------------------------------------------------------

/// Opens a browser save-file dialog and returns `(handle, stream)` for
/// streaming writes, or `null` if the user cancelled the dialog.
///
/// [suggestedName] is the suggested file name shown in the save dialog.
///
/// The caller MUST:
/// 1. Write decrypted chunks via [writeChunk]
/// 2. Close the stream via [closeStream] when done (or on error to abort)
///
/// If the user cancels the dialog, returns `null` — the caller should clean
/// up any UI state without showing an error.
Future<({JSObject handle, JSObject stream})?> openSaveStream(
  String suggestedName,
) async {
  final options = JSObject();
  options['suggestedName'] = suggestedName.toJS;

  try {
    final handle = await _showSaveFilePicker(options).toDart;

    final streamPromise = handle.callMethod('createWritable'.toJS);
    final stream =
        await (streamPromise! as JSPromise<JSAny?>).toDart as JSObject;

    return (handle: handle, stream: stream);
  } catch (_) {
    // User cancelled the dialog (AbortError) or API not available
    return null;
  }
}

/// Writes a decrypted chunk to the stream.
///
/// [bytes] is the plaintext chunk bytes. These are written immediately to
/// disk by the browser via JSUint8Array (BufferSource) — they do NOT
/// accumulate in Dart memory.
///
/// Sequential calls append to the file in order (the stream's write cursor
/// advances automatically).
Future<void> writeChunk(JSObject stream, Uint8List bytes) async {
  final writePromise = stream.callMethod('write'.toJS, bytes.toJS);
  await (writePromise! as JSPromise<JSAny?>).toDart;
}

/// Closes the writable stream, finalizing the file on disk.
///
/// MUST be called after the last chunk, or on error to abort the write.
/// After calling this, the stream is invalid and must not be used.
Future<void> closeStream(JSObject stream) async {
  final closePromise = stream.callMethod('close'.toJS);
  await (closePromise! as JSPromise<JSAny?>).toDart;
}
