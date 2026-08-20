/// AES-GCM 256 encryption/decryption via package:cryptography.
///
/// Uses the [AesGcm.with256bits] factory, which dispatches to the best
/// available implementation per platform:
/// - Web: crypto.subtle (WebCrypto) — hardware-accelerated (AES-NI,
///   ARMv8 crypto extensions), constant-time
/// - Native: pure-Dart implementation
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint keys, plaintext, IVs, or ciphertexts.
/// - NEVER reuse an IV with the same key. A new random 12-byte IV is
///   generated for EVERY encrypt() call.
/// - The GCM authentication tag is 128 bits. Any tampering with the
///   ciphertext (including flipping a single bit) causes decrypt() to
///   throw [VaultCipherException] — never returns garbage plaintext.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Thrown when AES-GCM decryption fails (wrong key, tampered ciphertext,
/// or corrupted data).
///
/// Always catch this — never let it propagate silently.
final class VaultCipherException implements Exception {
  const VaultCipherException(this.message);
  final String message;

  @override
  String toString() => 'VaultCipherException: $message';
}

/// AES-GCM 256 encryption.
///
/// ## Usage
/// ```dart
/// final cipher = VaultCipher();
/// final key = await VaultCipher.generateKey(); // 32 bytes for AES-256
/// final (iv, ciphertext) = await cipher.encrypt(key, plaintext);
/// final decrypted = await cipher.decrypt(key, iv, ciphertext);
/// ```
///
/// ## IV uniqueness guarantee
/// Every call to [encrypt] generates a fresh random 12-byte IV from the
/// platform CSPRNG. Re-using an IV with the same AES-GCM key catastrophically
/// breaks security — this class prevents that by design.
final class VaultCipher {
  /// AES-GCM IV length in bytes (96 bits, per NIST SP 800-38D §8.2.1).
  static const int ivLength = 12;

  /// GCM authentication tag length in bits (128 bits).
  static const int tagLength = 128;

  /// Shared [AesGcm] algorithm. Stateless — one instance serves all calls.
  static final AesGcm _aesGcm = AesGcm.with256bits();

  const VaultCipher();

  /// Encrypts [plaintext] with AES-256-GCM using a fresh random IV.
  ///
  /// Returns `(iv, ciphertext)` where:
  /// - [iv] is 12 random bytes (never reused)
  /// - [ciphertext] is `ciphertext ‖ tag` — the 16-byte GCM authentication
  ///   tag appended (same layout WebCrypto produced)
  ///
  /// [key] must be exactly 32 bytes (AES-256).
  ///
  /// Optional [iv] overrides the random IV generation — only use this when
  /// the IV is constructed deterministically (e.g. chunked encryption).
  /// Misusing this with a fixed or repeating IV breaks GCM security.
  ///
  /// Optional [additionalData] is authenticated but not encrypted (AAD).
  /// Used by chunked encryption to bind chunk metadata (index, is-last flag).
  Future<(Uint8List, Uint8List)> encrypt(
    Uint8List key,
    Uint8List plaintext, {
    Uint8List? iv,
    Uint8List? additionalData,
  }) async {
    _assertKeyLength(key);

    final effectiveIv = iv ?? randomBytes(ivLength);
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: effectiveIv,
      aad: additionalData ?? const <int>[],
    );

    // concatenation(nonce: false) = cipherText ‖ mac, mac = 16-byte GCM tag.
    return (effectiveIv, secretBox.concatenation(nonce: false));
  }

  /// Decrypts [ciphertext] with AES-256-GCM.
  ///
  /// [key] must be the same 32-byte key used for encryption.
  /// [iv] must be the 12-byte IV returned by [encrypt].
  ///
  /// Optional [additionalData] must match the AAD passed to [encrypt].
  ///
  /// Throws [VaultCipherException] if:
  /// - The GCM tag doesn't validate (wrong key, tampered data, corruption,
  ///   or mismatched AAD)
  /// - [key] is not 32 bytes
  /// - [iv] is not 12 bytes
  Future<Uint8List> decrypt(
    Uint8List key,
    Uint8List iv,
    Uint8List ciphertext, {
    Uint8List? additionalData,
  }) async {
    _assertKeyLength(key);
    if (iv.length != ivLength) {
      throw VaultCipherException(
        'IV must be $ivLength bytes, got ${iv.length}',
      );
    }
    if (ciphertext.length < 16) {
      throw const VaultCipherException(
        'Ciphertext too short: missing 16-byte GCM tag',
      );
    }

    final tagOffset = ciphertext.length - 16;
    final secretBox = SecretBox(
      ciphertext.sublist(0, tagOffset),
      nonce: iv,
      mac: Mac(ciphertext.sublist(tagOffset)),
    );

    try {
      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
        aad: additionalData ?? const <int>[],
      );
      return Uint8List.fromList(decrypted);
    } on SecretBoxAuthenticationError {
      throw const VaultCipherException(
        'Decryption failed: wrong key, tampered data, or corrupted ciphertext',
      );
    }
  }

  /// Generates a random 32-byte (256-bit) AES key from the platform CSPRNG.
  static Uint8List generateKey() => randomBytes(32);

  /// Generates [length] cryptographically secure random bytes from the
  /// platform CSPRNG: crypto.getRandomValues on the web, the OS CSPRNG
  /// on native (via [Random.secure]).
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static void _assertKeyLength(Uint8List key) {
    if (key.length != 32) {
      throw VaultCipherException(
        'AES-256 requires a 32-byte key, got ${key.length}',
      );
    }
  }
}
