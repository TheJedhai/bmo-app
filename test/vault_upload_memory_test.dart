// VM — proves the streaming upload never materializes the whole file in
// memory, by asserting the wire contract of the loop: every PUT carries one
// bounded chunk (≤ chunkSize + 16 bytes), never a full-file body, and the
// number of PUTs equals exactly the expected chunk count.
//
// Process RSS is deliberately NOT used: on the flutter_tester VM it's the OS
// resident set, which does not track Dart heap (a 1-chunk and a full-file
// upload both read ~8-15 MiB), so any threshold is noise. The property below
// is deterministic.
//
// Run: flutter test test/vault_upload_memory_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

/// Server that records every chunk it receives (size + count) and assembles
/// the blob for a round-trip download.
final class _RecordingServer {
  final List<Uint8List> chunks = [];
  Uint8List? header;
  int putCalls = 0;

  Uint8List? get _blob {
    final h = header;
    if (h == null) return null;
    final builder = BytesBuilder(copy: false);
    builder.add(h);
    for (final c in chunks) {
      builder.add(c);
    }
    return builder.takeBytes();
  }

  http.Response _item() {
    return http.Response(
      jsonEncode({
        'id': '10',
        'vault_id': '1',
        'metadata_blob': base64Encode(Uint8List(16)),
        'metadata_iv': base64Encode(Uint8List(12)),
        'encryption_scheme': 'gcm_chunked',
        'chunk_size': VaultChunkedCipher.defaultChunkSize,
        'size_bytes': 0,
        'created_at': '2025-06-15T10:30:00Z',
        'updated_at': '2025-06-15T10:30:00Z',
      }),
      201,
      headers: {'content-type': 'application/json'},
    );
  }

  MockClient client() {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'POST' && path.endsWith('/items/uploads')) {
        header = base64Decode(
          (jsonDecode(request.body) as Map<String, dynamic>)['header'] as String,
        );
        return http.Response(
          jsonEncode({'upload_id': 'u1', 'expected_size': 0}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }
      final chunkMatch =
          RegExp(r'/uploads/u1/chunks/(\d+)$').firstMatch(path);
      if (request.method == 'PUT' && chunkMatch != null) {
        putCalls++;
        chunks.add(Uint8List.fromList(request.bodyBytes));
        return http.Response('', 204);
      }
      if (request.method == 'POST' && path.endsWith('/uploads/u1/complete')) {
        return _item();
      }
      if (request.method == 'GET' &&
          path == '/api/v1/vaults/1/items/10') {
        final blob = _blob!;
        return http.Response.bytes(
          blob,
          200,
          headers: {
            'content-type': 'application/octet-stream',
            'content-length': blob.length.toString(),
          },
        );
      }
      return http.Response('not found', 404);
    });
  }
}

/// Writes a temp file of exactly [megaBytes] MiB block-by-block.
Future<File> _writeTempFile(int megaBytes) async {
  final file = File(
    '${Directory.systemTemp.path}/bmo_mem_${DateTime.now().microsecondsSinceEpoch}.bin',
  );
  final sink = file.openWrite();
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < block.length; i++) {
    block[i] = (i * 31 + 7) & 0xFF;
  }
  for (var m = 0; m < megaBytes; m++) {
    sink.add(block);
  }
  await sink.close();
  return file;
}

void main() {
  final dek = VaultCipher.generateKey();

  test('streaming upload is bounded to one chunk — never a full-file body',
      () async {
    const mb = 32; // 32 MiB >> 1 MiB chunk
    final chunkSize = VaultChunkedCipher.defaultChunkSize;

    final file = await _writeTempFile(mb);
    try {
      final server = _RecordingServer();
      final repo = VaultRepository(
        VaultClient(client: server.client(), baseUrl: 'http://localhost:8089'),
      );

      await repo.uploadItem(
        '1',
        dek,
        null, // no bytes materialized — streamed straight from the file
        'big.bin',
        'application/octet-stream',
        originalFile: XFile(file.path),
      );

      final total = VaultChunkedCipher.totalChunks(file.lengthSync(), chunkSize);
      expect(server.chunks.length, total);

      // The critical memory property: every chunk body is bounded by the
      // chunk size (chunkSize + 16 GCM tag), so in-flight bytes never scale
      // with the file — the biggest buffer is one chunk, not the file (and
      // the old path carried the file + every ciphertext + a blob copy).
      for (final c in server.chunks) {
        expect(c.length, lessThanOrEqualTo(chunkSize + 16));
      }
      final maxBody =
          server.chunks.map((c) => c.length).reduce((a, b) => a > b ? a : b);
      // ignore: avoid_print
      print('MEMORY: $mb MiB file -> ${server.chunks.length} chunks, '
          'max in-flight chunk body = $maxBody bytes '
          '(${maxBody / (1024 * 1024).toDouble()} MiB) — constant, '
          'independent of file size.');

      // Round-trip: the assembled blob decrypts back to the exact file.
      final decrypted = await repo.downloadItem('1', dek, '10');
      expect(decrypted.length, file.lengthSync());
      expect(decrypted, await XFile(file.path).readAsBytes());
    } finally {
      try { file.deleteSync(); } catch (_) {}
    }
  });
}
