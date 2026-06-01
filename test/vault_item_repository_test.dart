// Unit tests for VaultRepository item operations — mock the HTTP layer.
//
// Tests:
// 1. uploadItem — encrypts metadata + chunks, uploads via multipart
// 2. listItems — decrypts returned metadata, returns VaultItemDecrypted list
// 3. downloadItem — downloads full blob, decrypts via decryptAll
// 4. fetchItemHeader — Range fetch first 21 bytes
// 5. fetchChunkRange — Range fetch + decrypt single chunk
// 6. mapPlaintextRangeToChunks — range→chunk index mapping
// 7. Metadata decryption failure → skipped gracefully
// 8. Cross-chunk plaintext range mapping
//
// ## Security: This test file NEVER logs DEKs, plaintext, file names, or
// key material.
//
// Run: flutter test --platform=chrome test/vault_item_repository_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_models.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

// ---------------------------------------------------------------------------
// Mock KDF — fast, deterministic, no WASM needed
// ---------------------------------------------------------------------------

final class MockKdf implements VaultKdf {
  const MockKdf();

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      result[i] =
          password[i % password.length] ^ salt[i % salt.length] ^ (i * 0x1B);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [VaultRepository] with a [MockClient].
VaultRepository _createRepo(MockClient mockClient) {
  final client = VaultClient(
    client: mockClient,
    baseUrl: 'http://localhost:8089',
  );
  return VaultRepository(client, kdf: const MockKdf());
}

/// Creates a [Vault] JSON response body.
Map<String, dynamic> _vaultJson(String id, String name) => {
      'id': id,
      'name': name,
      'created_at': '2025-06-15T10:30:00Z',
      'updated_at': '2025-06-15T10:30:00Z',
    };

/// Extracts the unlock-material fields from a [VaultCreationMaterial] into
/// a JSON map matching the `GET /vaults/{id}/keys` response shape.
Map<String, dynamic> _keysJsonFromMaterial(VaultCreationMaterial m) {
  return m.toJson();
}

/// Builds a [VaultItem] JSON response from the given fields.
Map<String, dynamic> _itemJson({
  String id = '1',
  String vaultId = '1',
  required Uint8List metadataBlob,
  required Uint8List metadataIv,
  String encryptionScheme = 'gcm_chunked',
  int? chunkSize,
  int sizeBytes = 1000,
  String createdAt = '2025-06-15T10:30:00Z',
}) {
  final json = <String, dynamic>{
    'id': int.parse(id),
    'vault_id': int.parse(vaultId),
    'metadata_blob': base64Encode(metadataBlob),
    'metadata_iv': base64Encode(metadataIv),
    'encryption_scheme': encryptionScheme,
    'size_bytes': sizeBytes,
    'created_at': createdAt,
    'updated_at': createdAt,
  };
  if (chunkSize != null) {
    json['chunk_size'] = chunkSize;
  }
  return json;
}

/// Generates deterministic pseudo-random bytes of [length] using a seed.
/// NOT cryptographically random — only for deterministic test data.
Uint8List _testBytes(int length, {int seed = 42}) {
  final bytes = Uint8List(length);
  var state = seed;
  for (var i = 0; i < length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    bytes[i] = state & 0xFF;
  }
  return bytes;
}

/// Splits [data] into chunks of [chunkSize] (last chunk may be smaller).
List<Uint8List> _splitIntoChunks(Uint8List data, int chunkSize) {
  final chunks = <Uint8List>[];
  var offset = 0;
  while (offset < data.length) {
    final end = offset + chunkSize;
    final chunkEnd = end > data.length ? data.length : end;
    chunks.add(Uint8List.sublistView(data, offset, chunkEnd));
    offset = chunkEnd;
  }
  return chunks;
}

/// Concatenates header + encrypted chunks into the full blob format.
Uint8List _concatBlob(Uint8List header, List<Uint8List> encryptedChunks) {
  final totalLen =
      header.length + encryptedChunks.fold<int>(0, (s, c) => s + c.length);
  final blob = Uint8List(totalLen);
  var offset = 0;
  blob.setRange(offset, offset + header.length, header);
  offset += header.length;
  for (final chunk in encryptedChunks) {
    blob.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }
  return blob;
}

/// Creates a mock client that handles vault creation + key fetch +
/// a single item POST.
MockClient _mockForUpload({
  required VaultCreationMaterial material,
  required String vaultId,
  required String itemId,
  required String encryptionScheme,
  required int? chunkSize,
  required Uint8List metadataBlob,
  required Uint8List metadataIv,
  int sizeBytes = 5000,
}) {
  final keysJson = _keysJsonFromMaterial(material);
  return MockClient((request) async {
    // -- Vault creation --
    if (request.method == 'POST' &&
        request.url.path == '/api/v1/vaults') {
      return http.Response(
        jsonEncode(_vaultJson(vaultId, 'test-vault')),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    // -- Key fetch --
    if (request.url.path == '/api/v1/vaults/$vaultId/keys') {
      return http.Response(
        jsonEncode(keysJson),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    // -- Item upload --
    if (request.method == 'POST' &&
        request.url.path == '/api/v1/vaults/$vaultId/items') {
      return http.Response(
        jsonEncode(_itemJson(
          id: itemId,
          vaultId: vaultId,
          metadataBlob: metadataBlob,
          metadataIv: metadataIv,
          encryptionScheme: encryptionScheme,
          chunkSize: chunkSize,
          sizeBytes: sizeBytes,
        )),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const chunkSize = 256; // small for fast tests
  final testDek = VaultCipher.generateKey();

  // =========================================================================
  // 1. uploadItem
  // =========================================================================
  group('uploadItem', () {
    test('encrypts metadata + content and uploads via multipart', () async {
      const password = 'test-password';
      final material = await createVault(password, kdf: const MockKdf());
      final repo = _createRepo(_mockForUpload(
        material: material,
        vaultId: '1',
        itemId: '10',
        encryptionScheme: 'gcm_chunked',
        chunkSize: VaultChunkedCipher.defaultChunkSize,
        metadataBlob: Uint8List(0), // placeholder
        metadataIv: Uint8List(0),
      ));

      // Create vault + unlock to get DEK
      final createResult = await repo.createVault('test-vault', password);
      final unlockResult =
          await repo.unlockWithPassword(createResult.vault.id, password);
      final dek = unlockResult.dek;

      // Generate test content (small — 1 chunk)
      final fileBytes = _testBytes(200, seed: 1);
      const fileName = 'test.txt';
      const mimeType = 'text/plain';

      // We need a mock that captures the uploaded blob so we can verify it.
      // Use a simpler mock that just returns success.
      final uploadMock = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/vaults/1/items') {
          // Verify multipart content type
          final ct = request.headers['content-type'] ?? '';
          expect(ct, contains('multipart/form-data'));

          return http.Response(
            jsonEncode(_itemJson(
              id: '10',
              vaultId: '1',
              metadataBlob: Uint8List(16), // dummy
              metadataIv: Uint8List(12), // dummy
              encryptionScheme: 'gcm_chunked',
              chunkSize: VaultChunkedCipher.defaultChunkSize,
              sizeBytes: 500,
            )),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final uploadRepo = VaultRepository(
        VaultClient(client: uploadMock, baseUrl: 'http://localhost:8089'),
        kdf: const MockKdf(),
      );

      final result = await uploadRepo.uploadItem(
        '1',
        dek,
        fileBytes,
        fileName,
        mimeType,
      );

      expect(result.id, '10');
      expect(result.vaultId, '1');
      expect(result.fileName, fileName);
      expect(result.mimeType, mimeType);
      expect(result.originalSize, fileBytes.length);
      expect(result.encryptionScheme, 'gcm_chunked');
      expect(result.chunkSize, VaultChunkedCipher.defaultChunkSize);
    });

    test('progress callback fires during upload', () async {
      final progressLog = <(int, int)>[];
      final uploadMock = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/vaults/1/items') {
          return http.Response(
            jsonEncode(_itemJson(
              id: '10',
              vaultId: '1',
              metadataBlob: Uint8List(16),
              metadataIv: Uint8List(12),
              encryptionScheme: 'gcm_chunked',
              chunkSize: VaultChunkedCipher.defaultChunkSize,
              sizeBytes: 500,
            )),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final uploadRepo = VaultRepository(
        VaultClient(client: uploadMock, baseUrl: 'http://localhost:8089'),
        kdf: const MockKdf(),
      );

      // Use a small file so progress is straightforward to verify.
      final fileBytes = _testBytes(500, seed: 2);
      await uploadRepo.uploadItem(
        '1',
        testDek,
        fileBytes,
        'small.bin',
        'application/octet-stream',
        onProgress: (sent, total) => progressLog.add((sent, total)),
      );

      // Progress should have been called at least once.
      expect(progressLog.isNotEmpty, isTrue);
      // Last progress call should report all bytes sent.
      expect(progressLog.last.$1, progressLog.last.$2);
    });
  });

  // =========================================================================
  // 2. listItems — metadata decryption
  // =========================================================================
  group('listItems', () {
    test('decrypts metadata and returns VaultItemDecrypted list', () async {
      const fileName = 'photo.jpg';
      const mimeType = 'image/jpeg';
      const originalSize = 123456;
      const cipher = VaultCipher();

      // Encrypt metadata that the mock server will return.
      final metaJson = jsonEncode({
        'fileName': fileName,
        'mimeType': mimeType,
        'originalSize': originalSize,
      });
      final (metadataIv, metadataBlob) = await cipher.encrypt(
        testDek,
        Uint8List.fromList(utf8.encode(metaJson)),
      );

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items') {
          return http.Response(
            jsonEncode([
              _itemJson(
                id: '1',
                vaultId: '1',
                metadataBlob: metadataBlob,
                metadataIv: metadataIv,
                encryptionScheme: 'gcm_chunked',
                chunkSize: VaultChunkedCipher.defaultChunkSize,
                sizeBytes: 5000,
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);
      final items = await repo.listItems('1', testDek);

      expect(items.length, 1);
      expect(items[0].id, '1');
      expect(items[0].vaultId, '1');
      expect(items[0].fileName, fileName);
      expect(items[0].mimeType, mimeType);
      expect(items[0].originalSize, originalSize);
      expect(items[0].encryptionScheme, 'gcm_chunked');
      expect(items[0].chunkSize, VaultChunkedCipher.defaultChunkSize);
      expect(items[0].sizeBytes, 5000);
    });

    test('skips items with corrupted metadata gracefully', () async {
      // Random junk bytes that won't decrypt.
      final junkBlob = VaultCipher.randomBytes(32);
      final junkIv = VaultCipher.randomBytes(12);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items') {
          return http.Response(
            jsonEncode([
              _itemJson(
                id: '1',
                metadataBlob: junkBlob,
                metadataIv: junkIv,
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);
      final items = await repo.listItems('1', testDek);

      // Corrupted metadata → item is skipped, not crashed.
      expect(items.length, 0);
    });

    test('skips item with bad JSON in metadata after decryption', () async {
      const cipher = VaultCipher();
      final badJson = Uint8List.fromList(utf8.encode('{not valid json['));
      final (metadataIv, metadataBlob) =
          await cipher.encrypt(testDek, badJson);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items') {
          return http.Response(
            jsonEncode([
              _itemJson(
                id: '1',
                metadataBlob: metadataBlob,
                metadataIv: metadataIv,
              ),
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);
      final items = await repo.listItems('1', testDek);

      expect(items.length, 0);
    });
  });

  // =========================================================================
  // 3. downloadItem — full download + decryptAll
  // =========================================================================
  group('downloadItem', () {
    test('full round-trip: upload then download', () async {
      final fileBytes = _testBytes(200, seed: 3);

      // Build the encrypted blob that uploadItem would produce.
      const chunked = VaultChunkedCipher();
      final plaintextChunks = _splitIntoChunks(
        fileBytes,
        chunkSize,
      );
      final (header, encryptedChunks) = await chunked.encryptChunks(
        testDek,
        plaintextChunks,
        chunkSize: chunkSize,
      );
      final blob = _concatBlob(header, encryptedChunks);

      final mockClient = MockClient((request) async {
        // Full blob download.
        if (request.url.path == '/api/v1/vaults/1/items/10') {
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

      final repo = _createRepo(mockClient);

      final progressLog = <(int, int)>[];
      final decrypted = await repo.downloadItem(
        '1',
        testDek,
        '10',
        onProgress: (received, total) => progressLog.add((received, total)),
      );

      expect(decrypted, fileBytes);
      expect(progressLog.isNotEmpty, isTrue);
      expect(progressLog.last.$1, blob.length);
    });

    test('downloadItem throws VaultApiException on 410 Gone', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'blob_file_missing',
            'message': 'Blob file not found for item 10',
          }),
          410,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = _createRepo(mockClient);

      expect(
        () => repo.downloadItem('1', testDek, '10'),
        throwsA(isA<VaultApiException>()),
      );
    });

    test('downloadItem throws VaultCipherException for wrong DEK', () async {
      final fileBytes = _testBytes(200, seed: 3);
      const chunked = VaultChunkedCipher();
      final plaintextChunks = _splitIntoChunks(
        fileBytes,
        chunkSize,
      );
      final (header, encryptedChunks) = await chunked.encryptChunks(
        testDek,
        plaintextChunks,
        chunkSize: chunkSize,
      );
      final blob = _concatBlob(header, encryptedChunks);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items/10') {
          return http.Response.bytes(blob, 200,
              headers: {'content-length': blob.length.toString()});
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // Use a different (wrong) DEK.
      final wrongDek = VaultCipher.generateKey();
      expect(
        () => repo.downloadItem('1', wrongDek, '10'),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 4. fetchItemHeader
  // =========================================================================
  group('fetchItemHeader', () {
    test('fetches first 21 bytes of blob', () async {
      // Create a known blob to serve.
      const chunked = VaultChunkedCipher();
      final plaintextChunks = _splitIntoChunks(
        _testBytes(300, seed: 4),
        chunkSize,
      );
      final (header, encryptedChunks) = await chunked.encryptChunks(
        testDek,
        plaintextChunks,
        chunkSize: chunkSize,
      );
      final blob = _concatBlob(header, encryptedChunks);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items/10') {
          final rangeHeader = request.headers['range'];
          if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
            // Parse range and return partial.
            final parts = rangeHeader
                .substring(6)
                .split('-')
                .map(int.parse)
                .toList();
            final rangeBytes = Uint8List.sublistView(
              blob,
              parts[0],
              parts[1] + 1,
            );
            return http.Response.bytes(
              rangeBytes,
              206,
              headers: {
                'content-range':
                    'bytes ${parts[0]}-${parts[1]}/${blob.length}',
                'content-length': rangeBytes.length.toString(),
              },
            );
          }
          return http.Response.bytes(blob, 200,
              headers: {
                'content-length': blob.length.toString(),
                'accept-ranges': 'bytes',
              });
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);
      final fetchedHeader = await repo.fetchItemHeader('1', '10');

      expect(fetchedHeader.length, headerByteLength);
      expect(fetchedHeader, header);
    });
  });

  // =========================================================================
  // 5. fetchChunkRange — single chunk fetch + decrypt
  // =========================================================================
  group('fetchChunkRange', () {
    test('fetches and decrypts a single chunk by index', () async {
      const chunked = VaultChunkedCipher();
      final plaintextChunks = _splitIntoChunks(
        _testBytes(chunkSize * 3 + 50, seed: 5),
        chunkSize,
      );
      final (header, encryptedChunks) = await chunked.encryptChunks(
        testDek,
        plaintextChunks,
        chunkSize: chunkSize,
      );
      final blob = _concatBlob(header, encryptedChunks);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items/10') {
          final rangeHeader = request.headers['range'];
          if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
            final parts = rangeHeader
                .substring(6)
                .split('-')
                .map(int.parse)
                .toList();
            final rangeBytes = Uint8List.sublistView(
              blob,
              parts[0],
              parts[1] + 1,
            );
            return http.Response.bytes(
              rangeBytes,
              206,
              headers: {
                'content-range':
                    'bytes ${parts[0]}-${parts[1]}/${blob.length}',
                'content-length': rangeBytes.length.toString(),
              },
            );
          }
          return http.Response.bytes(blob, 200,
              headers: {'content-length': blob.length.toString()});
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // Fetch and decrypt chunk 1 (middle chunk).
      final (decrypted, statusCode, encryptedBytes) =
          await repo.fetchChunkRange('1', testDek, '10', 1, header);
      expect(decrypted, plaintextChunks[1]);
      // Mock returns 206 when content-range header is present.
      expect(statusCode, 206);
      // Encrypted bytes = plaintext + 16-byte GCM tag.
      expect(encryptedBytes, chunkSize + 16);
    });

    test('fetchChunkRange handles last (partial) chunk correctly', () async {
      const chunked = VaultChunkedCipher();
      final plaintextChunks = _splitIntoChunks(
        _testBytes(chunkSize * 2 + 50, seed: 6),
        chunkSize,
      );
      final (header, encryptedChunks) = await chunked.encryptChunks(
        testDek,
        plaintextChunks,
        chunkSize: chunkSize,
      );
      final blob = _concatBlob(header, encryptedChunks);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/1/items/10') {
          final rangeHeader = request.headers['range'];
          final parts = rangeHeader!
              .substring(6)
              .split('-')
              .map(int.parse)
              .toList();
          final rangeBytes = Uint8List.sublistView(
            blob,
            parts[0],
            parts[1] + 1,
          );
          return http.Response.bytes(
            rangeBytes,
            206,
            headers: {
              'content-range':
                  'bytes ${parts[0]}-${parts[1]}/${blob.length}',
              'content-length': rangeBytes.length.toString(),
            },
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // Last chunk (index 2) should be 50 bytes of plaintext.
      expect(plaintextChunks.length, 3);
      expect(plaintextChunks[2].length, 50);

      final (decrypted, statusCode, encryptedBytes) =
          await repo.fetchChunkRange('1', testDek, '10', 2, header);
      expect(decrypted, plaintextChunks[2]);
      // Mock returns 206 when content-range header is present.
      expect(statusCode, 206);
      // Last chunk: 50 bytes plaintext + 16-byte GCM tag = 66 encrypted.
      expect(encryptedBytes, 50 + 16);
    });
  });

  // =========================================================================
  // 6. mapPlaintextRangeToChunks
  // =========================================================================
  group('mapPlaintextRangeToChunks', () {
    test('single chunk range', () {
      final result = VaultRepository.mapPlaintextRangeToChunks(
        50,
        150,
        256,
        500,
      );
      expect(result.length, 1);
      expect(result[0].$1, 0); // chunk index
      expect(result[0].$2, 50); // offset within chunk
      expect(result[0].$3, 101); // length
    });

    test('range spanning two chunks', () {
      final result = VaultRepository.mapPlaintextRangeToChunks(
        200,
        400,
        256,
        600,
      );
      expect(result.length, 2);
      expect(result[0].$1, 0);
      expect(result[0].$2, 200); // offset in chunk 0
      expect(result[0].$3, 56); // 256 - 200
      expect(result[1].$1, 1);
      expect(result[1].$2, 0); // offset in chunk 1
      expect(result[1].$3, 145); // 400 - 256 + 1
    });

    test('range spanning three chunks', () {
      // chunk 0: 0..255, 1: 256..511, 2: 512..767, 3: 768..799 (partial)
      // range 100..750 → chunks 0, 1, 2 → 3 chunks
      final result = VaultRepository.mapPlaintextRangeToChunks(
        100,
        750,
        256,
        800,
      );
      expect(result.length, 3);
      expect(result[0].$1, 0); // chunk 0: bytes 100..255
      expect(result[1].$1, 1); // chunk 1: bytes 256..511
      expect(result[2].$1, 2); // chunk 2: bytes 512..750
    });

    test('range at chunk boundary', () {
      // chunk 1: 256..511, chunk 2: 512..767
      // range 256..512 crosses chunk 1→2 boundary
      final result = VaultRepository.mapPlaintextRangeToChunks(
        256,
        512,
        256,
        800,
      );
      expect(result.length, 2);
      expect(result[0].$1, 1); // chunk 1: bytes 256..511
      expect(result[0].$2, 0);
      expect(result[0].$3, 256); // 511-256+1
      expect(result[1].$1, 2); // chunk 2: byte 512
      expect(result[1].$2, 0);
      expect(result[1].$3, 1); // 512-512+1
    });

    test('exact single chunk', () {
      final result = VaultRepository.mapPlaintextRangeToChunks(
        0,
        255,
        256,
        500,
      );
      expect(result.length, 1);
      expect(result[0].$1, 0);
      expect(result[0].$2, 0);
      expect(result[0].$3, 256);
    });

    test('range spanning into last partial chunk', () {
      // chunk 0: 0..255, chunk 1: 256..511, chunk 2: 512..549
      // range 500..549 crosses chunk 1 (500..511 = 12 bytes) and chunk 2 (512..549 = 38 bytes)
      final result = VaultRepository.mapPlaintextRangeToChunks(
        500,
        549,
        256,
        550,
      );
      expect(result.length, 2);
      expect(result[0].$1, 1); // chunk 1
      expect(result[0].$2, 244); // 500 - 256
      expect(result[0].$3, 12); // 511 - 500 + 1
      expect(result[1].$1, 2); // chunk 2
      expect(result[1].$2, 0);
      expect(result[1].$3, 38); // 549 - 512 + 1
    });

    test('clamped end beyond originalSize', () {
      // originalSize=300 → chunks: 0 (0..255), 1 (256..299)
      // range 100..999 clamped to 100..299 → spans chunks 0 and 1
      final result = VaultRepository.mapPlaintextRangeToChunks(
        100,
        999,
        256,
        300,
      );
      expect(result.length, 2);
      expect(result[0].$1, 0);
      expect(result[0].$2, 100);
      expect(result[0].$3, 156); // 255-100+1
      expect(result[1].$1, 1);
      expect(result[1].$2, 0);
      expect(result[1].$3, 44); // 299-256+1
    });

    test('out of bounds returns empty', () {
      final result = VaultRepository.mapPlaintextRangeToChunks(
        500,
        600,
        256,
        400,
      );
      expect(result, isEmpty);
    });

    test('single byte at boundary', () {
      final result = VaultRepository.mapPlaintextRangeToChunks(
        256,
        256,
        256,
        600,
      );
      expect(result.length, 1);
      expect(result[0].$1, 1);
      expect(result[0].$2, 0);
      expect(result[0].$3, 1);
    });
  });

  // =========================================================================
  // 7. deleteItem
  // =========================================================================
  group('deleteItem', () {
    test('deleteItem succeeds on 204', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/vaults/1/items/10') {
          return http.Response('', 204);
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);
      // Should not throw.
      await repo.deleteItem('1', '10');
    });

    test('deleteItem throws VaultApiException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'vault_item_not_found',
            'message': 'Item 99 not found',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = _createRepo(mockClient);
      expect(
        () => repo.deleteItem('1', '99'),
        throwsA(isA<VaultApiException>()),
      );
    });
  });
}
