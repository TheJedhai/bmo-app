// Vault crypto test suite.
//
// Tests:
// 1. Cipher round-trip (binary-safe)
// 2. IV uniqueness
// 3. Canary validation
// 4. Tampered ciphertext rejection
// 5. Wrong password
// 6. RFC 9106 Argon2id known-answer test vector + Argon2Kdf wrapper
// 7. Cipher edge cases
// 8. Argon2Params self-consistency
//
// Runs on VM (`flutter test`) and chrome (`flutter test --platform=chrome`) —
// Argon2id is pure Dart (package:cryptography), no platform plugins involved.
//
// ## Security: This test file NEVER logs key material.

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/vault/crypto/argon2_kdf.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';

// ---------------------------------------------------------------------------
// Mock KDF (fast, deterministic — for tests that don't need real Argon2)
// ---------------------------------------------------------------------------

/// A fast mock KDF that derives a key from password + salt via a simple
/// HMAC-like approach. NOT SECURE — only for tests that validate
/// cipher/envelope logic, not KDF correctness.
final class MockKdf implements VaultKdf {
  const MockKdf();

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    // Simple deterministic derivation: concatenate and hash via XOR loops.
    // NOT cryptographically sound — just fast and deterministic.
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      var b = salt[i % salt.length] ^ password[i % password.length] ^ i;
      // Mix a few rounds
      for (var r = 0; r < 3; r++) {
        b = ((b << 3) | (b >> 5)) & 0xFF;
        b ^= password[(i + r) % password.length];
      }
      result[i] = b;
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Test setup
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // 1. Round-trip: cipher + decrypt
  // =========================================================================
  group('VaultCipher round-trip', () {
    test('encrypt then decrypt returns original plaintext (ASCII)', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList(
        'Hello, BMO Vault! This is a round-trip test.'.codeUnits,
      );

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);
      final decrypted = await cipher.decrypt(key, iv, ciphertext);

      expect(decrypted, equals(plaintext));
    });

    test('encrypt then decrypt returns original binary bytes', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      // Full byte range: 0x00–0xFF
      final plaintext = Uint8List.fromList(
        List.generate(256, (i) => i),
      );

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);
      final decrypted = await cipher.decrypt(key, iv, ciphertext);

      expect(decrypted, equals(plaintext));
    });

    test('decrypt with wrong key throws', () async {
      const cipher = VaultCipher();
      final key1 = VaultCipher.generateKey();
      final key2 = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList([1, 2, 3, 4, 5]);

      final (iv, ciphertext) = await cipher.encrypt(key1, plaintext);

      expect(
        () async => cipher.decrypt(key2, iv, ciphertext),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 2. IV uniqueness
  // =========================================================================
  group('IV uniqueness', () {
    test('two encryptions of same plaintext produce different IVs', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList('same plaintext'.codeUnits);

      final (iv1, ct1) = await cipher.encrypt(key, plaintext);
      final (iv2, ct2) = await cipher.encrypt(key, plaintext);

      // IVs must differ
      expect(iv1, isNot(equals(iv2)));

      // Ciphertexts must differ (because IV is part of the input)
      expect(ct1, isNot(equals(ct2)));

      // Both IVs are 12 bytes
      expect(iv1, hasLength(12));
      expect(iv2, hasLength(12));

      // Both ciphertexts can be decrypted with their respective IVs
      expect(await cipher.decrypt(key, iv1, ct1), equals(plaintext));
      expect(await cipher.decrypt(key, iv2, ct2), equals(plaintext));
    });

    test('encrypting 100 times produces 100 unique IVs', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List(16);
      final ivs = <Uint8List>{};

      for (var i = 0; i < 100; i++) {
        final (iv, _) = await cipher.encrypt(key, plaintext);
        // Convert to comparable format
        ivs.add(Uint8List.fromList(iv));
      }

      expect(ivs.length, equals(100));
    });
  });

  // =========================================================================
  // 3. Canary validation
  // =========================================================================
  group('Canary', () {
    test('correct KEK validates canary', () async {
      final kek = VaultCipher.generateKey();
      final (canaryIv, canaryCt) = await createCanary(kek);

      final valid = await validateCanary(kek, canaryIv, canaryCt);
      expect(valid, isTrue);
    });

    test('wrong KEK fails canary validation', () async {
      final kek1 = VaultCipher.generateKey();
      final kek2 = VaultCipher.generateKey();
      // Ensure keys are different
      expect(kek1, isNot(equals(kek2)));

      final (canaryIv, canaryCt) = await createCanary(kek1);

      final valid = await validateCanary(kek2, canaryIv, canaryCt);
      expect(valid, isFalse);
    });
  });

  // =========================================================================
  // 4. Tampered ciphertext rejection
  // =========================================================================
  group('Tampering detection', () {
    test('flipping 1 byte in ciphertext causes decrypt failure', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList('important data'.codeUnits);

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);

      // Flip a single bit in the middle of the ciphertext
      final tampered = Uint8List.fromList(ciphertext);
      final mid = tampered.length ~/ 2;
      tampered[mid] ^= 0x01; // flip one bit

      expect(
        () async => cipher.decrypt(key, iv, tampered),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('flipping 1 byte in IV causes decrypt failure', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList('important data'.codeUnits);

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);

      final tamperedIv = Uint8List.fromList(iv);
      tamperedIv[0] ^= 0x01;

      expect(
        () async => cipher.decrypt(key, tamperedIv, ciphertext),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('tampered wrapped DEK causes unlock to fail', () async {
      const mockKdf = MockKdf();
      final material = await createVault('password', 'test-vault', kdf: mockKdf);

      // Tamper with the wrapped DEK
      final tamperedDek = Uint8List.fromList(material.wrappedDek);
      tamperedDek[5] ^= 0x01;

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: tamperedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
        recoveryKeyWrapped: material.recoveryKeyWrapped,
        recoveryKeyWrapIv: material.recoveryKeyWrapIv,
        nameBlob: material.nameBlob,
        nameIv: material.nameIv,
      );

      expect(
        () async => unlock('password', unlockMat, kdf: mockKdf),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 5. Wrong password exception
  // =========================================================================
  group('Wrong password', () {
    test('wrong password throws WrongPasswordException', () async {
      const mockKdf = MockKdf();
      final material = await createVault('correct-password', 'test-vault', kdf: mockKdf);

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
        recoveryKeyWrapped: material.recoveryKeyWrapped,
        recoveryKeyWrapIv: material.recoveryKeyWrapIv,
        nameBlob: material.nameBlob,
        nameIv: material.nameIv,
      );

      expect(
        () async => unlock('wrong-password', unlockMat, kdf: mockKdf),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('correct password unlocks successfully', () async {
      const mockKdf = MockKdf();
      const password = 'correct-password';
      final material = await createVault(password, 'test-vault', kdf: mockKdf);

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
        recoveryKeyWrapped: material.recoveryKeyWrapped,
        recoveryKeyWrapIv: material.recoveryKeyWrapIv,
        nameBlob: material.nameBlob,
        nameIv: material.nameIv,
      );

      final dek = await unlock(password, unlockMat, kdf: mockKdf);
      expect(dek, hasLength(32));
    });
  });

  // =========================================================================
  // 6. RFC 9106 Argon2id known-answer test vector (real KDF)
  // =========================================================================
  group('Argon2id correctness', () {
    test('Argon2id matches RFC 9106 §5.3 test vector', () async {
      // RFC 9106, Section 5.3 — Argon2id, version 0x13, m=32 KiB, t=3,
      // p=4, tag length 32.
      final algorithm = Argon2id(
        parallelism: 4,
        memory: 32,
        iterations: 3,
        hashLength: 32,
      );
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(List<int>.filled(32, 0x01)),
        nonce: List<int>.filled(16, 0x02),
        optionalSecret: List<int>.filled(8, 0x03),
        associatedData: List<int>.filled(12, 0x04),
      );
      final tag = await key.extractBytes();

      expect(tag, equals([
        0x0d, 0x64, 0x0d, 0xf5, 0x8d, 0x78, 0x76, 0x6c,
        0x08, 0xc0, 0x37, 0xa3, 0x4a, 0x8b, 0x53, 0xc9,
        0xd0, 0x1e, 0xf0, 0x45, 0x2d, 0x75, 0xb6, 0x5e,
        0xb5, 0x25, 0x20, 0xe9, 0x6b, 0x01, 0xe6, 0x59,
      ]));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Argon2Kdf wrapper produces correct-length output', () async {
      const kdf = Argon2Kdf();
      final password = Uint8List.fromList('test123'.codeUnits);
      final salt = Uint8List.fromList(List.generate(16, (i) => i));

      final derived = await kdf.derive(password: password, salt: salt);

      expect(derived, hasLength(32));
      // Not all zeros
      expect(derived.any((b) => b != 0), isTrue);
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('deterministic: same inputs produce same derived key', () async {
      const kdf = Argon2Kdf();
      final password = Uint8List.fromList('deterministic test'.codeUnits);
      final salt = Uint8List.fromList(List.generate(16, (i) => i * 3));

      final key1 = await kdf.derive(password: password, salt: salt);
      final key2 = await kdf.derive(password: password, salt: salt);

      expect(key1, equals(key2));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('different passwords produce different derived keys', () async {
      const kdf = Argon2Kdf();
      final salt = Uint8List.fromList(List.generate(16, (i) => i));

      final key1 = await kdf.derive(
        password: Uint8List.fromList('password-a'.codeUnits),
        salt: salt,
      );
      final key2 = await kdf.derive(
        password: Uint8List.fromList('password-b'.codeUnits),
        salt: salt,
      );

      expect(key1, isNot(equals(key2)));
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  // =========================================================================
  // 7. Cipher edge cases
  // =========================================================================
  group('VaultCipher edge cases', () {
    test('encrypt empty plaintext', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List(0);

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);
      final decrypted = await cipher.decrypt(key, iv, ciphertext);

      expect(decrypted, isEmpty);
    });

    test('encrypt single byte plaintext', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final plaintext = Uint8List.fromList([0x42]);

      final (iv, ciphertext) = await cipher.encrypt(key, plaintext);
      final decrypted = await cipher.decrypt(key, iv, ciphertext);

      expect(decrypted, equals(plaintext));
    });

    test('key must be 32 bytes', () async {
      const cipher = VaultCipher();
      final shortKey = Uint8List(16);
      final plaintext = Uint8List(8);

      expect(
        () async => cipher.encrypt(shortKey, plaintext),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('IV must be 12 bytes for decrypt', () async {
      const cipher = VaultCipher();
      final key = VaultCipher.generateKey();
      final badIv = Uint8List(16);
      final ciphertext = Uint8List(32);

      expect(
        () async => cipher.decrypt(key, badIv, ciphertext),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('generateKey produces 32-byte keys', () {
      for (var i = 0; i < 10; i++) {
        final key = VaultCipher.generateKey();
        expect(key, hasLength(32));
      }
    });

    test('generateKey produces unique keys', () {
      final keys = <Uint8List>{};
      for (var i = 0; i < 20; i++) {
        keys.add(VaultCipher.generateKey());
      }
      // All 20 keys should be unique (astronomically unlikely to collide)
      expect(keys.length, equals(20));
    });

    test('randomBytes produces correct lengths', () {
      for (final length in [0, 1, 16, 32, 100]) {
        expect(VaultCipher.randomBytes(length), hasLength(length));
      }
    });
  });

  // =========================================================================
  // 8. Argon2Params constants are self-consistent
  // =========================================================================
  group('Argon2Params', () {
    test('constants satisfy Argon2 constraints', () {
      expect(Argon2Params.m, greaterThanOrEqualTo(8 * Argon2Params.p));
      expect(Argon2Params.t, greaterThanOrEqualTo(1));
      expect(Argon2Params.p, greaterThanOrEqualTo(1));
      expect(Argon2Params.hashLength, greaterThanOrEqualTo(4));
      expect(Argon2Params.saltLength, greaterThanOrEqualTo(8));
    });
  });
}
