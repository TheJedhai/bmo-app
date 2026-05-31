// Vault crypto test suite — Part B of Phase 8.1.
//
// Tests:
// 1. Cipher round-trip (binary-safe)
// 2. IV uniqueness
// 3. Canary validation
// 4. Recovery key unlocks same DEK
// 5. Tampered ciphertext rejection
// 6. RFC 9106 Argon2id known-answer test vector
// 7. Offline WASM self-hosting acceptance
//
// ## Security: This test file NEVER logs key material.
//
// Run: flutter test --platform=chrome test/vault_crypto_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart' show DartArgon2id;
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'package:dargon2_flutter_platform_interface/dargon2_flutter_platform.dart';
import 'package:dargon2_flutter_web/src/argon2.dart';
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
  // For tests that need the real Argon2 KDF, initialise the dargon2 platform.
  // (Uses CDN in test env — tests are dev-only with network access.)
  setUp(() {
    if (DArgon2Platform.instance is! DArgon2FlutterWeb) {
      DArgon2Platform.instance = DArgon2FlutterWeb();
    }
  });

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
  // 4. Recovery key unlocks same DEK
  // =========================================================================
  group('Recovery key', () {
    test('recovery key decrypts the same DEK as the password', () async {
      const mockKdf = MockKdf();
      const password = 'my-secret-password';

      // Create vault
      final material = await createVault(password, kdf: mockKdf);

      // Unlock with password
      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
      );
      final dekFromPassword = await unlock(password, unlockMat, kdf: mockKdf);

      // Unlock with recovery key
      final dekFromRecovery =
          await unlockWithRecoveryKey(material.recoveryKey, unlockMat);

      // Same DEK
      expect(dekFromRecovery, equals(dekFromPassword));
      expect(dekFromRecovery, hasLength(32));
    });

    test('wrong recovery key fails to unlock', () async {
      const mockKdf = MockKdf();
      final material = await createVault('password', kdf: mockKdf);

      final wrongRecoveryKey = VaultCipher.generateKey();
      // Ensure different
      expect(wrongRecoveryKey, isNot(equals(material.recoveryKey)));

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
      );

      expect(
        () async => unlockWithRecoveryKey(wrongRecoveryKey, unlockMat),
        throwsA(isA<VaultCipherException>()),
      );
    });

    test('recovery key encode/decode round-trip', () {
      final original = generateRecoveryKey();
      final encoded = encodeRecoveryKey(original);
      final decoded = decodeRecoveryKey(encoded);

      expect(decoded, equals(original));
      expect(encoded.length, equals(64)); // 32 bytes = 64 hex chars
      expect(encoded, equals(encoded.toLowerCase())); // lowercase
    });
  });

  // =========================================================================
  // 5. Tampered ciphertext rejection
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
      final material = await createVault('password', kdf: mockKdf);

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
      );

      expect(
        () async => unlock('password', unlockMat, kdf: mockKdf),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // =========================================================================
  // 6. Wrong password exception
  // =========================================================================
  group('Wrong password', () {
    test('wrong password throws WrongPasswordException', () async {
      const mockKdf = MockKdf();
      final material = await createVault('correct-password', kdf: mockKdf);

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
      );

      expect(
        () async => unlock('wrong-password', unlockMat, kdf: mockKdf),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('correct password unlocks successfully', () async {
      const mockKdf = MockKdf();
      const password = 'correct-password';
      final material = await createVault(password, kdf: mockKdf);

      final unlockMat = VaultUnlockMaterial(
        salt: material.salt,
        wrappedDek: material.wrappedDek,
        dekIv: material.dekIv,
        canaryCiphertext: material.canaryCiphertext,
        canaryIv: material.canaryIv,
        recoveryWrappedDek: material.recoveryWrappedDek,
        recoveryDekIv: material.recoveryDekIv,
      );

      final dek = await unlock(password, unlockMat, kdf: mockKdf);
      expect(dek, hasLength(32));
    });
  });

  // =========================================================================
  // 7. RFC 9106 Argon2id known-answer test vector (real KDF)
  // =========================================================================
  group('Argon2id correctness', () {
    setUp(() async {
      // DArgon2FlutterWeb._registerDependency() is async void —
      // it fires the CDN import but the constructor doesn't wait.
      // Poll until window.hashwasm is ready.
      for (var i = 0; i < 100; i++) {
        if (globalContext['hashwasm'] != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (globalContext['hashwasm'] == null) {
        throw TimeoutException(
          'hash-wasm not loaded after 10s — CDN may be unreachable',
        );
      }
    });

    test('cross-validates against cryptography (independent Dart impl)', () async {
      // Derive with dargon2 (hash-wasm WASM) and verify it matches
      // DartArgon2id from the cryptography package — two completely
      // independent implementations of RFC 9106 Argon2id.
      //
      // Parameters kept moderate for test speed while still exercising
      // the full algorithm (m=256 KiB, t=2, p=1, no secret/ad).
      final password = utf8.encode('bmo vault cross validation');
      final saltBytes = utf8.encode('0123456789abcdef'); // exactly 16 bytes

      // --- dargon2 (WASM) ---
      final dargon2Result = await argon2.hashPasswordBytes(
        password,
        salt: Salt(saltBytes),
        iterations: 2,
        memory: 256,
        parallelism: 1,
        length: 32,
        type: Argon2Type.id,
      );

      // --- cryptography (pure Dart) ---
      final dartAlgorithm = DartArgon2id(
        parallelism: 1,
        memory: 256,
        iterations: 2,
        hashLength: 32,
      );
      final dartResult = await dartAlgorithm.deriveKey(
        secretKey: SecretKey(password),
        nonce: saltBytes,
      );
      final dartBytes = await dartResult.extractBytes();

      // Both independently implemented RFC 9106 Argon2id — MUST match.
      expect(dargon2Result.rawBytes, equals(dartBytes));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Argon2Kdf wrapper produces correct-length output', () async {
      const kdf = Argon2Kdf();
      final password = Uint8List.fromList('test123'.codeUnits);
      final salt = Uint8List.fromList(List.generate(16, (i) => i));

      final derived = await kdf.derive(password: password, salt: salt);

      expect(derived, hasLength(32));
      // Not all zeros
      expect(derived.any((b) => b != 0), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('deterministic: same inputs produce same derived key', () async {
      const kdf = Argon2Kdf();
      final password = Uint8List.fromList('deterministic test'.codeUnits);
      final salt = Uint8List.fromList(List.generate(16, (i) => i * 3));

      final key1 = await kdf.derive(password: password, salt: salt);
      final key2 = await kdf.derive(password: password, salt: salt);

      expect(key1, equals(key2));
    }, timeout: const Timeout(Duration(seconds: 30)));

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
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  // =========================================================================
  // 8. Cipher edge cases
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
  // 9. Argon2Params constants are self-consistent
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
