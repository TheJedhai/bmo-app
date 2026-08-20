// VaultCipher test suite — AES-GCM 256 via package:cryptography.
//
// Tests:
// 1. RFC 5116 / McGrew-Viega §A.1 known-answer vectors (AES-256-GCM):
//    - Test Case 13: empty plaintext, empty AAD
//    - Test Case 14: 16-byte plaintext, empty AAD
//    - Test Case 16: 60-byte plaintext with AAD
// 2. Round-trip with AAD; wrong AAD / wrong key / tampered tag all fail
// 3. Chunked blob layout: 21-byte header, nonce = nonce_prefix ‖ index
//    (u32 BE), multi-chunk round-trip
//
// ## Security: This test file NEVER logs key material.
//
// Run: flutter test test/vault_cipher_test.dart
//      flutter test --platform=chrome test/vault_cipher_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _hex(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s+'), '');
  final bytes = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

String _toHex(List<int> bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Uint8List _patternBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i & 0xFF;
  }
  return bytes;
}

void main() {
  const cipher = VaultCipher();

  // -------------------------------------------------------------------------
  // Known-answer vectors (McGrew-Viega GCM spec, Appendix B — AES-256 cases)
  // -------------------------------------------------------------------------

  group('known-answer vectors (AES-256-GCM)', () {
    test('Test Case 13: empty plaintext, empty AAD', () async {
      final key = _hex('00000000000000000000000000000000'
          '00000000000000000000000000000000');
      final iv = _hex('000000000000000000000000');

      final (_, ct) = await cipher.encrypt(key, Uint8List(0), iv: iv);

      expect(_toHex(ct), '530f8afbc74536b9a963b4f1c4cb738b');
    });

    test('Test Case 14: 16-byte plaintext, empty AAD', () async {
      final key = _hex('00000000000000000000000000000000'
          '00000000000000000000000000000000');
      final iv = _hex('000000000000000000000000');
      final pt = Uint8List(16);

      final (_, ct) = await cipher.encrypt(key, pt, iv: iv);

      expect(
        _toHex(ct),
        'cea7403d4d606b6e074ec5d3baf39d18'
        'd0d1c8a799996bf0265b98b5d48ab919',
      );
    });

    test('Test Case 16: 60-byte plaintext with AAD', () async {
      final key = _hex('feffe9928665731c6d6a8f9467308308'
          'feffe9928665731c6d6a8f9467308308');
      final iv = _hex('cafebabefacedbaddecaf888');
      final aad = _hex('feedfacedeadbeeffeedfacedeadbeefabaddad2');
      final pt = _hex('d9313225f88406e5a55909c5aff5269a'
          '86a7a9531534f7da2e4c303d8a318a72'
          '1c3c0c95956809532fcf0e2449a6b525'
          'b16aedf5aa0de657ba637b39');

      final (_, ct) =
          await cipher.encrypt(key, pt, iv: iv, additionalData: aad);

      expect(
        _toHex(ct),
        '522dc1f099567d07f47f37a32a84427d'
        '643a8cdcbfe5c0c97598a2bd2555d1aa'
        '8cb08e48590dbb3da7b08b1056828838'
        'c5f61e6393ba7a0abcc9f662'
        '76fc6ece0f4e1768cddf8853bb2d551b',
      );
    });

    test('Test Case 16 decrypts back with correct AAD', () async {
      final key = _hex('feffe9928665731c6d6a8f9467308308'
          'feffe9928665731c6d6a8f9467308308');
      final iv = _hex('cafebabefacedbaddecaf888');
      final aad = _hex('feedfacedeadbeeffeedfacedeadbeefabaddad2');
      final pt = _hex('d9313225f88406e5a55909c5aff5269a'
          '86a7a9531534f7da2e4c303d8a318a72'
          '1c3c0c95956809532fcf0e2449a6b525'
          'b16aedf5aa0de657ba637b39');
      final ct = _hex('522dc1f099567d07f47f37a32a84427d'
          '643a8cdcbfe5c0c97598a2bd2555d1aa'
          '8cb08e48590dbb3da7b08b1056828838'
          'c5f61e6393ba7a0abcc9f662'
          '76fc6ece0f4e1768cddf8853bb2d551b');

      final decrypted =
          await cipher.decrypt(key, iv, ct, additionalData: aad);

      expect(decrypted, pt);
    });
  });

  // -------------------------------------------------------------------------
  // AAD and tamper rejection
  // -------------------------------------------------------------------------

  group('AAD authentication', () {
    final key = VaultCipher.generateKey();
    final plaintext = _patternBytes(128);

    test('round-trip with AAD succeeds', () async {
      final aad = _patternBytes(26); // 21-byte header + index + is-last shape

      final (iv, ct) =
          await cipher.encrypt(key, plaintext, additionalData: aad);
      final decrypted =
          await cipher.decrypt(key, iv, ct, additionalData: aad);

      expect(decrypted, plaintext);
    });

    test('wrong AAD fails authentication', () async {
      final aad = _patternBytes(26);
      final wrongAad = Uint8List.fromList(aad);
      wrongAad[0] ^= 0x01;

      final (iv, ct) =
          await cipher.encrypt(key, plaintext, additionalData: aad);

      expect(
        () => cipher.decrypt(key, iv, ct, additionalData: wrongAad),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('missing AAD fails authentication', () async {
      final (iv, ct) =
          await cipher.encrypt(key, plaintext, additionalData: _patternBytes(26));

      expect(
        () => cipher.decrypt(key, iv, ct),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('wrong key fails authentication', () async {
      final (iv, ct) = await cipher.encrypt(key, plaintext);

      expect(
        () => cipher.decrypt(VaultCipher.generateKey(), iv, ct),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered tag fails authentication', () async {
      final (iv, ct) = await cipher.encrypt(key, plaintext);
      final tampered = Uint8List.fromList(ct);
      tampered[tampered.length - 1] ^= 0x01; // flip bit in tag

      expect(
        () => cipher.decrypt(key, iv, tampered),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Chunked cipher blob layout
  // -------------------------------------------------------------------------

  group('chunked blob layout', () {
    const chunked = VaultChunkedCipher();
    final dek = VaultCipher.generateKey();

    test('header is 21 bytes with format version 2', () {
      final header = VaultChunkedCipher.buildHeader(
        noncePrefix: VaultCipher.randomBytes(8),
        chunkSize: VaultChunkedCipher.defaultChunkSize,
        originalSize: 12345,
      );

      expect(header.length, headerByteLength);
      expect(header[0], 2);
    });

    test('multi-chunk file: nonce = nonce_prefix ‖ index (u32 BE)', () async {
      // 3 chunks: two full 64-byte chunks + one partial.
      const chunkSize = 64;
      final chunks = <Uint8List>[
        _patternBytes(chunkSize),
        _patternBytes(chunkSize),
        _patternBytes(23),
      ];

      final (header, encrypted) =
          await chunked.encryptChunks(dek, chunks, chunkSize: chunkSize);
      final (_, noncePrefix, _, _) = VaultChunkedCipher.parseHeader(header);

      for (var i = 0; i < chunks.length; i++) {
        // Rebuild the per-chunk nonce straight from the spec:
        // nonce = nonce_prefix (8 bytes) ‖ index (u32 BE, 4 bytes).
        final nonce = Uint8List(VaultCipher.ivLength);
        nonce.setRange(0, 8, noncePrefix);
        final indexData = ByteData.sublistView(nonce, 8, 12);
        indexData.setUint32(0, i);

        // AAD = header (21 bytes) ‖ index (u32 BE) ‖ is_last (1 byte).
        final aad = Uint8List(header.length + 5);
        aad.setRange(0, header.length, header);
        ByteData.sublistView(aad, header.length, header.length + 4)
            .setUint32(0, i);
        aad[header.length + 4] = i == chunks.length - 1 ? 1 : 0;

        final decrypted = await cipher.decrypt(
          dek,
          nonce,
          encrypted[i],
          additionalData: aad,
        );

        expect(decrypted, chunks[i],
            reason: 'chunk $i decrypts with spec-built nonce/AAD');
      }
    });

    test('multi-chunk round-trip via decryptAll', () async {
      const chunkSize = 64;
      final chunks = <Uint8List>[
        _patternBytes(chunkSize),
        _patternBytes(chunkSize),
        _patternBytes(23),
      ];

      final (header, encrypted) =
          await chunked.encryptChunks(dek, chunks, chunkSize: chunkSize);
      final blob = Uint8List(
          header.length + encrypted.fold(0, (sum, c) => sum + c.length));
      var offset = 0;
      blob.setRange(0, header.length, header);
      offset += header.length;
      for (final chunk in encrypted) {
        blob.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      final decrypted = await chunked.decryptAll(dek, header, blob);

      final expected = Uint8List(chunkSize + chunkSize + 23);
      expected.setRange(0, chunkSize, chunks[0]);
      expected.setRange(chunkSize, chunkSize * 2, chunks[1]);
      expected.setRange(chunkSize * 2, expected.length, chunks[2]);
      expect(decrypted, expected);
    });

    test('full chunk ciphertext is plaintext + 16-byte tag', () async {
      const chunkSize = 64;
      final (_, encrypted) = await chunked.encryptChunks(
        dek,
        [_patternBytes(chunkSize), _patternBytes(5)],
        chunkSize: chunkSize,
      );

      expect(encrypted[0].length, chunkSize + 16);
      expect(encrypted[1].length, 5 + 16);
    });
  });
}
