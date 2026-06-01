// Integration test: Vault item upload/download end-to-end against disposable
// bmo-server instance.
//
// ## REQUIREMENTS
// This test requires a DISPOSABLE bmo-server instance running on port 8090
// with a temporary database and blob directory. NEVER run against production.
//
// ### Starting the disposable server
// ```bash
// # One-time setup:
// export BMO_TEST_DB=$(mktemp /tmp/bmo-e2e-XXXXXX.db)
// export BMO_TEST_BLOBS=$(mktemp -d /tmp/bmo-e2e-blobs-XXXXXX)
// BMO_DB_PATH=$BMO_TEST_DB \
// BMO_VAULT_BLOB_DIR=$BMO_TEST_BLOBS \
// BMO_HOST=127.0.0.1 \
// ~/Library/Application\ Support/BMO/venv/bin/python \
//   -m uvicorn bmo_server.main:app --port 8090 --host 127.0.0.1
//
// # After test, cleanup:
// rm -f $BMO_TEST_DB
// rm -rf $BMO_TEST_BLOBS
// ```
//
// Or use the helper script:
// ```bash
// test/vault_item_integration_run.sh
// ```
//
// Run the test:
// ```bash
// flutter test --platform=chrome test/vault_item_integration_test.dart
// ```
//
// ## Test flow (Phase 8.3c spec):
// 1. Start disposable bmo-server (external — see above)
// 2. Create vault + unlock → get DEK
// 3. Generate ~5 MiB deterministic pseudo-random bytes
// 4. uploadItem with fileName + MIME
// 5. listItems → verify decrypted name/MIME
// 6. downloadItem → compare byte-by-byte with original
// 7. fetchChunkRange for middle chunk → verify plaintext slice
// 8. fetchItemHeader → verify header parsing
// 9. mapPlaintextRangeToChunks cross-chunk → verify range
// 10. deleteItem + deleteVault (cleanup)
//
// ## Security: This test NEVER logs DEKs, plaintext, file names, or
// key material.
@Tags(['integration'])
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Use a disposable bmo-server on port 8090 to avoid clashing with the
/// production server on 8089.
const _testServerUrl = 'http://127.0.0.1:8090';

// ---------------------------------------------------------------------------
// Mock KDF — fast, deterministic, no WASM
// ---------------------------------------------------------------------------

/// Mock KDF for E2E tests. The real Argon2id KDF requires the hash-wasm
/// WASM module which is loaded via web/index.html — unavailable in the
/// Flutter test environment. Argon2id correctness is tested by
/// vault_crypto_test.dart; the item E2E test focuses on the integration of
/// chunked encryption with the server.
final class _MockKdf implements VaultKdf {
  const _MockKdf();

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

/// Creates a [VaultRepository] pointed at the disposable test server,
/// using a mock KDF that doesn't require the hash-wasm WASM module.
VaultRepository _createRepo() {
  final client = http.Client();
  return VaultRepository(
    VaultClient(client: client, baseUrl: _testServerUrl),
    kdf: const _MockKdf(),
  );
}

/// Deterministic pseudo-random bytes via a linear congruential generator.
/// NOT cryptographically random — only for reproducible test data.
Uint8List _testBytes(int length, {int seed = 42}) {
  final bytes = Uint8List(length);
  var state = seed;
  for (var i = 0; i < length; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    bytes[i] = state & 0xFF;
  }
  return bytes;
}

/// Unique suffix for test vault names to avoid collisions across runs.
final _runId = Random().nextInt(99999);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const testPassword = 'e2e-item-test-pw-8.3c';
  String? vaultId;
  String? itemId;
  Uint8List? dek;

  group('Vault item E2E integration', () {
    // -------------------------------------------------------------------
    // 1. Create vault + unlock
    // -------------------------------------------------------------------
    test('1. create vault + unlock → get DEK', () async {
      final repo = _createRepo();

      final result = await repo.createVault(
        'e2e-items-$_runId',
        testPassword,
      );
      expect(result.vault.id, isNotEmpty);
      vaultId = result.vault.id;

      final unlockResult =
          await repo.unlockWithPassword(vaultId!, testPassword);
      dek = unlockResult.dek;
      expect(dek!.length, 32);
    });

    // -------------------------------------------------------------------
    // 2. Upload ~5 MiB item
    // -------------------------------------------------------------------
    const fileName = 'test-video.mp4';
    const mimeType = 'video/mp4';

    test('2. uploadItem — ~5 MiB pseudo-random bytes', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);

      // ~5 MiB = 5 * 1024 * 1024 = 5 242 880 bytes → 5 full chunks + 1 partial
      const fileSize = 5 * 1024 * 1024; // exactly 5 MiB
      final fileBytes = _testBytes(fileSize, seed: 100);

      final progressLog = <(int, int)>[];
      final result = await repo.uploadItem(
        vaultId!,
        dek!,
        fileBytes,
        fileName,
        mimeType,
        onProgress: (sent, total) => progressLog.add((sent, total)),
      );

      expect(result.id, isNotEmpty);
      itemId = result.id;
      expect(result.fileName, fileName);
      expect(result.mimeType, mimeType);
      expect(result.originalSize, fileSize);
      expect(result.encryptionScheme, 'gcm_chunked');
      expect(result.chunkSize, VaultChunkedCipher.defaultChunkSize);

      // Progress should have been called multiple times (multi-megabyte upload).
      expect(progressLog.length, greaterThanOrEqualTo(1));
      // Final progress report should show all bytes sent.
      expect(progressLog.last.$1, progressLog.last.$2);
    });

    // -------------------------------------------------------------------
    // 3. listItems — verify decrypted metadata
    // -------------------------------------------------------------------
    test('3. listItems — name and MIME decrypted correctly', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);

      final items = await repo.listItems(vaultId!, dek!);

      expect(items.length, 1);
      expect(items[0].id, itemId);
      expect(items[0].fileName, fileName);
      expect(items[0].mimeType, mimeType);
      expect(items[0].originalSize, 5 * 1024 * 1024);
      expect(items[0].encryptionScheme, 'gcm_chunked');
    });

    // -------------------------------------------------------------------
    // 4. downloadItem — full decrypt, byte-by-byte comparison
    // -------------------------------------------------------------------
    test('4. downloadItem — full decrypt, byte-by-byte match', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);
      expect(itemId, isNotNull);

      const fileSize = 5 * 1024 * 1024;
      final original = _testBytes(fileSize, seed: 100);

      final progressLog = <(int, int)>[];
      final decrypted = await repo.downloadItem(
        vaultId!,
        dek!,
        itemId!,
        onProgress: (received, total) => progressLog.add((received, total)),
      );

      expect(decrypted.length, fileSize);
      expect(decrypted, original); // exact byte-by-byte match

      // Progress should have been called for a multi-megabyte download.
      expect(progressLog.length, greaterThanOrEqualTo(1));
      expect(progressLog.last.$1, progressLog.last.$2);
    });

    // -------------------------------------------------------------------
    // 5. fetchItemHeader — header bytes
    // -------------------------------------------------------------------
    test('5. fetchItemHeader — returns valid header', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(itemId, isNotNull);

      final header = await repo.fetchItemHeader(vaultId!, itemId!);

      expect(header.length, headerByteLength);

      // Parse header to verify it's valid.
      final (version, noncePrefix, chunkSize, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      expect(version, 2);
      expect(noncePrefix.length, 8);
      expect(chunkSize, VaultChunkedCipher.defaultChunkSize);
      expect(originalSize, 5 * 1024 * 1024);
    });

    // -------------------------------------------------------------------
    // 6. fetchChunkRange — middle chunk (index 2)
    // -------------------------------------------------------------------
    test('6. fetchChunkRange — middle chunk decrypts correctly', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);
      expect(itemId, isNotNull);

      const fileSize = 5 * 1024 * 1024;
      const chunkSize = VaultChunkedCipher.defaultChunkSize;
      final original = _testBytes(fileSize, seed: 100);

      // Fetch header first.
      final header = await repo.fetchItemHeader(vaultId!, itemId!);

      // Decrypt chunk 2 (bytes 2 097 152 .. 3 145 727 in plaintext).
      const chunkIndex = 2;
      final decrypted = await repo.fetchChunkRange(
        vaultId!,
        dek!,
        itemId!,
        chunkIndex,
        header,
      );

      // Verify against the same slice of the original plaintext.
      final expectedStart = chunkIndex * chunkSize;
      final expectedEnd = (chunkIndex + 1) * chunkSize;
      final expectedSlice = Uint8List.sublistView(
        original,
        expectedStart,
        expectedEnd,
      );

      expect(decrypted, expectedSlice);
    });

    // -------------------------------------------------------------------
    // 7. Cross-chunk plaintext range
    // -------------------------------------------------------------------
    test('7. cross-chunk range mapping and fetch/decrypt', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);
      expect(itemId, isNotNull);

      const fileSize = 5 * 1024 * 1024;
      const chunkSize = VaultChunkedCipher.defaultChunkSize;
      final original = _testBytes(fileSize, seed: 100);

      final header = await repo.fetchItemHeader(vaultId!, itemId!);

      // Request a plaintext range that crosses chunk 1→2 boundary:
      // bytes 1 500 000 .. 2 100 000
      const plainStart = 1500000;
      const plainEnd = 2100000;

      final chunks = VaultRepository.mapPlaintextRangeToChunks(
        plainStart,
        plainEnd,
        chunkSize,
        fileSize,
      );

      expect(chunks.length, 2);

      // Fetch and decrypt each needed chunk, then assemble.
      final decryptedParts = <Uint8List>[];
      for (final (ci, offset, length) in chunks) {
        final chunkPlain = await repo.fetchChunkRange(
          vaultId!,
          dek!,
          itemId!,
          ci,
          header,
        );
        decryptedParts.add(Uint8List.sublistView(chunkPlain, offset, offset + length));
      }

      // Concatenate.
      final totalLen = decryptedParts.fold<int>(0, (s, p) => s + p.length);
      final assembled = Uint8List(totalLen);
      var pos = 0;
      for (final part in decryptedParts) {
        assembled.setRange(pos, pos + part.length, part);
        pos += part.length;
      }

      // Compare with original slice.
      final expected = Uint8List.sublistView(
        original,
        plainStart,
        plainEnd + 1,
      );

      expect(assembled.length, plainEnd - plainStart + 1);
      expect(assembled, expected);
    });

    // -------------------------------------------------------------------
    // 8. fetchChunkRange for last (partial) chunk
    // -------------------------------------------------------------------
    test('8. fetchChunkRange — last partial chunk', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(dek, isNotNull);
      expect(itemId, isNotNull);

      const fileSize = 5 * 1024 * 1024; // exactly 5 MiB → 5 full chunks
      const chunkSize = VaultChunkedCipher.defaultChunkSize;
      final totalChunks =
          VaultChunkedCipher.totalChunks(fileSize, chunkSize);

      // 5 MiB is exactly 5 × 1 MiB, so the last chunk (index 4) should be
      // exactly chunkSize bytes — there is no partial chunk.
      expect(totalChunks, 5);

      final original = _testBytes(fileSize, seed: 100);
      final header = await repo.fetchItemHeader(vaultId!, itemId!);

      // Decrypt last chunk.
      const lastIdx = 4;
      final decrypted = await repo.fetchChunkRange(
        vaultId!,
        dek!,
        itemId!,
        lastIdx,
        header,
      );

      final expectedSlice = Uint8List.sublistView(
        original,
        lastIdx * chunkSize,
        fileSize,
      );

      expect(decrypted, expectedSlice);
    });

    // -------------------------------------------------------------------
    // 9. Cleanup: delete item + vault
    // -------------------------------------------------------------------
    test('9. cleanup — delete item and vault', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);
      expect(itemId, isNotNull);

      // Delete item first.
      await repo.deleteItem(vaultId!, itemId!);

      // Verify item is gone by checking list.
      final items = await repo.listItems(vaultId!, dek!);
      expect(items.where((i) => i.id == itemId), isEmpty);

      // Delete vault.
      await repo.deleteVault(vaultId!);

      // Verify vault is gone — list all vaults, confirm our id is absent.
      // (bmo-server does NOT have GET /vaults/{id}; uses list + key fetch.)
      final allVaults = await repo.listVaults();
      expect(allVaults.where((v) => v.id == vaultId), isEmpty);
    });
  });
}
