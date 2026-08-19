// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use,
// ignore_for_file: lines_longer_than_80_chars

// Web branch of the file stream writer seam (chrome only).
//
// Fakes window.showSaveFilePicker + createWritable to verify the lifecycle
// without a real save dialog:
// 1. cancel (AbortError) → openFileStreamWriter returns null
// 2. abort() sends abort to the stream and NEVER close() — a partial file
//    cannot materialize in the destination
// 3. finalize() sends close(); abort() afterwards is a no-op
//
// Run: flutter test --platform=chrome test/file_stream_writer_web_test.dart

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/platform/file_stream_writer.dart';

void runFileStreamWriterWebTests() {
  test('cancelar o diálogo retorna null', () async {
    _installFakePicker(cancel: true);
    final writer = await openFileStreamWriter('vault.bin');
    expect(writer, isNull);
  });

  test('abort envia abort e nunca close', () async {
    final calls = _installFakePicker();
    final writer = await openFileStreamWriter('vault.bin');
    expect(writer, isNotNull);

    await writer!.writeChunk(Uint8List.fromList([1, 2, 3]));
    await writer.abort();

    expect(calls, contains('abort'));
    expect(calls, isNot(contains('close')));
  });

  test('finalize envia close; abort depois é no-op', () async {
    final calls = _installFakePicker();
    final writer = await openFileStreamWriter('vault.bin');
    await writer!.finalize();

    expect(calls, contains('close'));

    await writer.abort();
    expect(calls.where((c) => c == 'abort'), isEmpty);
  });
}

/// Substitui window.showSaveFilePicker por um fake que devolve um stream
/// gravando os nomes dos métodos chamados em [calls]. Métodos fake devolvem
/// JSPromise de verdade (produção espera promise em write/close/abort/
/// createWritable); assinatura toJS não aceita Future, então as promises
/// são construídas com `Future.toJS` dentro de closure síncrona.
List<String> _installFakePicker({bool cancel = false}) {
  final calls = <String>[];
  final window = globalContext['window']! as JSObject;

  JSObject makeStream() {
    final stream = JSObject();
    stream['write'] = ((JSAny chunk) {
      calls.add('write');
      return Future<JSAny?>.value().toJS;
    }).toJS;
    stream['close'] = (() {
      calls.add('close');
      return Future<JSAny?>.value().toJS;
    }).toJS;
    stream['abort'] = (() {
      calls.add('abort');
      return Future<JSAny?>.value().toJS;
    }).toJS;
    return stream;
  }

  window['showSaveFilePicker'] = ((JSObject options) {
    if (cancel) return Future<JSObject>.error(Exception('AbortError')).toJS;
    final handle = JSObject();
    handle['createWritable'] = (() => Future<JSObject>.value(
      makeStream(),
    ).toJS).toJS;
    return Future<JSObject>.value(handle).toJS;
  }).toJS;

  return calls;
}
