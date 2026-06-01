// Vault chunked cipher test suite — Phase 8.3b.
//
// Tests:
// 1. Round-trip multi-chunk (3.5× chunk_size → partial last chunk)
// 2. decryptChunk by index returns correct slice
// 3. Nonce uniqueness across all chunks of a file
// 4. Anti-reordering: wrong index or swapped chunks → decrypt fails
// 5. Anti-truncation: missing last chunk → decryptAll throws
// 6. Tampering: flipped byte in ciphertext → decrypt fails
// 7. Byte-range calculation matches actual blob positions
// 8. Single-chunk file (smaller than chunk size)
//
// ## Security: This test file NEVER logs key material.
//
// Run: flutter test --platform=chrome test/vault_chunked_cipher_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a deterministic plaintext of [length] bytes: [0, 1, 2, ..., 255, 0, 1, ...].
Uint8List _patternBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i & 0xFF;
  }
  return bytes;
}

/// Splits [data] into chunks of [chunkSize] (last chunk may be smaller).
List<Uint8List> _splitChunks(Uint8List data, int chunkSize) {
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
Uint8List _buildBlob(Uint8List header, List<Uint8List> encryptedChunks) {
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  /// Smaller chunk size for fast, deterministic tests.
  const testChunkSize = 256;

  // =========================================================================
  // 1. Round-trip multi-chunk
  // =========================================================================
  group('round-trip multi-chunk', () {
    test('decryptAll returns exact original bytes (3.5× chunk, partial last)',
        () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();

      // 3.5 × testChunkSize = 256 * 3 + 128 = 896 bytes → 4 chunks
      final original = _patternBytes(testChunkSize * 3 + testChunkSize ~/ 2);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      expect(plaintextChunks.length, equals(4));
      expect(plaintextChunks[3].length, equals(testChunkSize ~/ 2));

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      expect(encryptedChunks.length, equals(4));

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);

      expect(decrypted, equals(original));
    });

    test('decryptAll works with exactly one full chunk', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      expect(plaintextChunks.length, equals(1));

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);

      expect(decrypted, equals(original));
    });

    test('decryptAll works with multiple full chunks (no partial last)',
        () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3); // 3 full chunks
      final plaintextChunks = _splitChunks(original, testChunkSize);

      expect(plaintextChunks.length, equals(3));
      expect(plaintextChunks[2].length, equals(testChunkSize));

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);

      expect(decrypted, equals(original));
    });

    test('round-trip with default 1 MiB chunk size', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();

      // 2.5 MiB → 3 chunks at 1 MiB default
      final original =
          _patternBytes(VaultChunkedCipher.defaultChunkSize * 2 +
              VaultChunkedCipher.defaultChunkSize ~/ 2);
      final plaintextChunks =
          _splitChunks(original, VaultChunkedCipher.defaultChunkSize);

      expect(plaintextChunks.length, equals(3));

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
      );

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);

      expect(decrypted, equals(original));
    });
  });

  // =========================================================================
  // 2. decryptChunk by index returns correct slice
  // =========================================================================
  group('decryptChunk by index', () {
    test('each chunk decrypts to the correct plaintext slice', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3 + 100);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      for (var i = 0; i < encryptedChunks.length; i++) {
        final decrypted = await chunked.decryptChunk(
          dek,
          header,
          i,
          encryptedChunks[i],
        );
        expect(decrypted, equals(plaintextChunks[i]),
            reason: 'Chunk $i mismatch');
      }
    });

    test('decryptChunk works without needing other chunks', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 4);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Decrypt only chunk 2 — ignore the rest entirely.
      final decrypted = await chunked.decryptChunk(
        dek,
        header,
        2,
        encryptedChunks[2],
      );
      expect(decrypted, equals(plaintextChunks[2]));
    });

    test('decryptChunk with out-of-range index throws', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      expect(
        () async => chunked.decryptChunk(dek, header, 1, encryptedChunks[0]),
        throwsA(isA<VaultCipherException>()),
      );

      expect(
        () async => chunked.decryptChunk(dek, header, -1, encryptedChunks[0]),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 3. Nonce uniqueness
  // =========================================================================
  group('nonce uniqueness', () {
    test('any two chunks of the same file have different nonces', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 5);
      final plaintextChunks = _splitChunks(original, testChunkSize);
      final (header, _) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Parse header and reconstruct nonces to verify uniqueness.
      final (_, noncePrefix, chunkSize, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      final total = VaultChunkedCipher.totalChunks(originalSize, chunkSize);

      // Build nonces for each chunk index.
      final nonces = <Uint8List>[];
      for (var i = 0; i < total; i++) {
        // Reconstruct the nonce the same way the cipher does.
        final nonce = Uint8List(VaultCipher.ivLength);
        nonce.setRange(0, 8, noncePrefix);
        // encodeUint32BE of chunk index into bytes 8-11
        nonce[8] = (i >> 24) & 0xFF;
        nonce[9] = (i >> 16) & 0xFF;
        nonce[10] = (i >> 8) & 0xFF;
        nonce[11] = i & 0xFF;
        nonces.add(nonce);
      }

      // All nonces must be distinct.
      final seen = <String>{};
      for (final n in nonces) {
        final key = base64Encode(n);
        expect(seen.contains(key), isFalse,
            reason: 'Nonce reused across chunks of the same file');
        seen.add(key);
      }
    });
  });

  // =========================================================================
  // 4. Anti-reordering
  // =========================================================================
  group('anti-reordering', () {
    test('decrypting chunk j with index i (i ≠ j) fails', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Try to decrypt chunk 2's bytes claiming they're chunk 1.
      expect(
        () async => chunked.decryptChunk(dek, header, 1, encryptedChunks[2]),
        throwsA(isA<VaultCipherException>()),
      );

      // Try to decrypt chunk 0's bytes claiming they're chunk 2.
      expect(
        () async => chunked.decryptChunk(dek, header, 2, encryptedChunks[0]),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('swapped chunks in blob cause decryptAll to fail', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Swap chunk 0 and chunk 1 in the blob.
      final swapped = [encryptedChunks[1], encryptedChunks[0], encryptedChunks[2]];
      final tamperedBlob = _buildBlob(header, swapped);

      expect(
        () async => chunked.decryptAll(dek, header, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 5. Anti-truncation
  // =========================================================================
  group('anti-truncation', () {
    test('removing last chunk makes decryptAll throw', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Build blob without the last chunk.
      final truncatedChunks = encryptedChunks.sublist(0, encryptedChunks.length - 1);
      final truncatedBlob = _buildBlob(header, truncatedChunks);

      expect(
        () async => chunked.decryptAll(dek, header, truncatedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('truncation error message mentions truncation or last chunk', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 2);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      final truncatedChunks = encryptedChunks.sublist(0, 1);
      final truncatedBlob = _buildBlob(header, truncatedChunks);

      try {
        await chunked.decryptAll(dek, header, truncatedBlob);
        fail('Expected VaultCipherException');
      } on VaultCipherException catch (e) {
        expect(
          e.message.toLowerCase(),
          anyOf(contains('truncat'), contains('last chunk')),
        );
      }
    });
  });

  // =========================================================================
  // 6. Tampering
  // =========================================================================
  group('tampering', () {
    test('flipping one byte in a chunk ciphertext makes it fail', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Flip a byte in chunk 1.
      final tampered = Uint8List.fromList(encryptedChunks[1]);
      tampered[10] ^= 0x01;

      expect(
        () async => chunked.decryptChunk(dek, header, 1, tampered),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered chunk in full blob causes decryptAll to fail', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Tamper with chunk 1.
      final tampered = Uint8List.fromList(encryptedChunks[1]);
      tampered[5] ^= 0xFF;
      final tamperedChunks = [
        encryptedChunks[0],
        tampered,
        encryptedChunks[2],
      ];
      final tamperedBlob = _buildBlob(header, tamperedChunks);

      expect(
        () async => chunked.decryptAll(dek, header, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampering with header causes parse or decrypt failure', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 2);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Tamper with the nonce prefix in the header.
      final tamperedHeader = Uint8List.fromList(header);
      tamperedHeader[5] ^= 0x01;
      final tamperedBlob = _buildBlob(tamperedHeader, encryptedChunks);

      expect(
        () async => chunked.decryptAll(dek, tamperedHeader, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 7. Byte-range calculation
  // =========================================================================
  group('byte-range calculation', () {
    test('chunkByteRange matches actual position in blob', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 4 + 73);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      final blob = _buildBlob(header, encryptedChunks);

      // Verify each chunk's range matches its actual position.
      var expectedStart = headerByteLength;
      for (var i = 0; i < encryptedChunks.length; i++) {
        final (start, end) = chunked.chunkByteRange(header, i);
        expect(start, equals(expectedStart), reason: 'Chunk $i start');
        final expectedEnd =
            expectedStart + encryptedChunks[i].length - 1;
        expect(end, equals(expectedEnd), reason: 'Chunk $i end');

        // Verify the bytes at that range are the encrypted chunk.
        final rangeBytes = Uint8List.sublistView(blob, start, end + 1);
        expect(rangeBytes, equals(encryptedChunks[i]));

        expectedStart += encryptedChunks[i].length;
      }
    });

    test('chunkByteRange last chunk has correct (smaller) size', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 2 + 50);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Last chunk plaintext is 50 bytes → encrypted is 50+16=66 bytes.
      final (start, end) = chunked.chunkByteRange(header, 2);
      final rangeLen = end - start + 1;
      expect(rangeLen, equals(50 + 16));
      expect(rangeLen, equals(encryptedChunks[2].length));
    });

    test('chunkByteRange out-of-range throws', () {
      const chunked = VaultChunkedCipher();
      final header = VaultChunkedCipher.buildHeader(
        noncePrefix: Uint8List(8),
        chunkSize: testChunkSize,
        originalSize: testChunkSize,
      );

      expect(
        () => chunked.chunkByteRange(header, 1),
        throwsA(isA<VaultCipherException>()),
      );
      expect(
        () => chunked.chunkByteRange(header, -1),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 8. Single-chunk file
  // =========================================================================
  group('single-chunk file', () {
    test('file smaller than chunk size works and is marked as last', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(100); // much smaller than testChunkSize
      final plaintextChunks = _splitChunks(original, testChunkSize);

      expect(plaintextChunks.length, equals(1));

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      expect(encryptedChunks.length, equals(1));

      final (_, _, chunkSize, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      expect(originalSize, equals(100));
      expect(VaultChunkedCipher.totalChunks(originalSize, chunkSize),
          equals(1));

      // decryptChunk should work.
      final decrypted =
          await chunked.decryptChunk(dek, header, 0, encryptedChunks[0]);
      expect(decrypted, equals(original));

      // decryptAll should work.
      final blob = _buildBlob(header, encryptedChunks);
      final decryptedAll = await chunked.decryptAll(dek, header, blob);
      expect(decryptedAll, equals(original));
    });

    test('single byte file works', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = Uint8List.fromList([0x42]);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);
      expect(decrypted, equals(original));
    });

    test('empty file works', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = Uint8List(0);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        [original],
        chunkSize: testChunkSize,
      );

      final (_, _, _, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      expect(originalSize, equals(0));

      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);
      expect(decrypted, equals(original));
    });
  });

  // =========================================================================
  // 9. Header integrity
  // =========================================================================
  group('header integrity', () {
    test('header too short throws', () {
      expect(
        () => VaultChunkedCipher.parseHeader(Uint8List(10)),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('unsupported format version throws', () {
      final badHeader = Uint8List(headerByteLength);
      badHeader[0] = 99; // unsupported version

      expect(
        () => VaultChunkedCipher.parseHeader(badHeader),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('buildHeader + parseHeader round-trip', () {
      final noncePrefix = VaultCipher.randomBytes(8);
      const chunkSize = 4096;
      const originalSize = 12345678;

      final header = VaultChunkedCipher.buildHeader(
        noncePrefix: noncePrefix,
        chunkSize: chunkSize,
        originalSize: originalSize,
      );

      final (version, parsedPrefix, parsedChunkSize, parsedOriginalSize) =
          VaultChunkedCipher.parseHeader(header);

      expect(version, equals(2));
      expect(parsedPrefix, equals(noncePrefix));
      expect(parsedChunkSize, equals(chunkSize));
      expect(parsedOriginalSize, equals(originalSize));
    });

    test('totalChunks calculation', () {
      expect(VaultChunkedCipher.totalChunks(0, 256), equals(1));
      expect(VaultChunkedCipher.totalChunks(1, 256), equals(1));
      expect(VaultChunkedCipher.totalChunks(256, 256), equals(1));
      expect(VaultChunkedCipher.totalChunks(257, 256), equals(2));
      expect(VaultChunkedCipher.totalChunks(512, 256), equals(2));
    });
  });

  // =========================================================================
  // 10. Security regression — header authentication & anti-truncation
  // =========================================================================
  group('security regression', () {
    test('tampered original_size → 0 makes decryptAll throw (not return empty)',
        () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Mutate original_size in the header to 0.
      final tamperedHeader = Uint8List.fromList(header);
      // original_size is at bytes 13-20 (8 bytes big-endian u64)
      for (var j = 13; j < 21; j++) {
        tamperedHeader[j] = 0;
      }

      final tamperedBlob = _buildBlob(tamperedHeader, encryptedChunks);

      // Must throw — NOT silently return empty plaintext.
      expect(
        () async => chunked.decryptAll(dek, tamperedHeader, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered chunk_size in header makes decryptAll throw', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Mutate chunk_size in the header (bytes 9-12).
      final tamperedHeader = Uint8List.fromList(header);
      tamperedHeader[9] = 0x00;
      tamperedHeader[10] = 0x00;
      tamperedHeader[11] = 0x04;
      tamperedHeader[12] = 0x00; // chunk_size = 1024 (was 256)

      final tamperedBlob = _buildBlob(tamperedHeader, encryptedChunks);

      expect(
        () async => chunked.decryptAll(dek, tamperedHeader, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered nonce_prefix in header makes decryptAll throw', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Flip a byte in the nonce_prefix (bytes 1-8).
      final tamperedHeader = Uint8List.fromList(header);
      tamperedHeader[3] ^= 0xFF;

      final tamperedBlob = _buildBlob(tamperedHeader, encryptedChunks);

      expect(
        () async => chunked.decryptAll(dek, tamperedHeader, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered format_version in header makes parseHeader throw', () {
      final noncePrefix = VaultCipher.randomBytes(8);
      final header = VaultChunkedCipher.buildHeader(
        noncePrefix: noncePrefix,
        chunkSize: 256,
        originalSize: 512,
      );

      final tamperedHeader = Uint8List.fromList(header);
      tamperedHeader[0] = 99; // unsupported version

      expect(
        () => VaultChunkedCipher.parseHeader(tamperedHeader),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('empty file round-trip authenticates sentinel chunk', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = Uint8List(0);

      // encryptChunks with empty list (not [Uint8List(0)]) — the fix must
      // produce a sentinel chunk anyway.
      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        <Uint8List>[],
        chunkSize: testChunkSize,
      );

      // Must have produced exactly 1 sentinel chunk.
      expect(encryptedChunks.length, equals(1));

      final (_, _, _, originalSize) =
          VaultChunkedCipher.parseHeader(header);
      expect(originalSize, equals(0));

      // decryptAll must authenticate the sentinel (is_last=1) and succeed.
      final blob = _buildBlob(header, encryptedChunks);
      final decrypted = await chunked.decryptAll(dek, header, blob);
      expect(decrypted, equals(original)); // Uint8List(0)
    });

    test('empty file tampered to non-empty via header fails', () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();

      // Encrypt empty file → 1 sentinel chunk.
      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        <Uint8List>[],
        chunkSize: testChunkSize,
      );

      // Tamper original_size from 0 → 256 (claim non-empty).
      final tamperedHeader = Uint8List.fromList(header);
      // original_size bytes 13-20: set to 256 (0x100)
      tamperedHeader[19] = 0x01;
      tamperedHeader[20] = 0x00; // already 0 but be explicit

      final tamperedBlob = _buildBlob(tamperedHeader, encryptedChunks);

      // decryptAll with tampered header: AAD mismatch because header changed
      // → GCM fails.
      expect(
        () async => chunked.decryptAll(dek, tamperedHeader, tamperedBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('remove all chunks — only header remains — throws truncation error',
        () async {
      const chunked = VaultChunkedCipher();
      final dek = VaultCipher.generateKey();
      final original = _patternBytes(testChunkSize * 3);
      final plaintextChunks = _splitChunks(original, testChunkSize);

      final (header, encryptedChunks) = await chunked.encryptChunks(
        dek,
        plaintextChunks,
        chunkSize: testChunkSize,
      );

      // Build blob with NO chunks — only the header. original_size is intact.
      final headerOnlyBlob = Uint8List.fromList(header);

      expect(
        () async => chunked.decryptAll(dek, header, headerOnlyBlob),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });
}
