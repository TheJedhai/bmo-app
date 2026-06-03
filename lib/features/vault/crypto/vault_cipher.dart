/// AES-GCM 256 encryption/decryption via browser WebCrypto (crypto.subtle).
///
/// ## Why WebCrypto and not a Dart lib?
/// The browser's crypto.subtle is:
/// - Hardware-accelerated (AES-NI on x86, ARMv8 crypto extensions)
/// - Constant-time (resistant to timing side-channels)
/// - Zero dependency — no extra bytes in the Flutter bundle
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint keys, plaintext, IVs, or ciphertexts.
/// - NEVER reuse an IV with the same key. A new random 12-byte IV is
///   generated for EVERY encrypt() call.
/// - The GCM authentication tag is 128 bits. Any tampering with the
///   ciphertext (including flipping a single bit) causes decrypt() to
///   throw [VaultCipherException] — never returns garbage plaintext.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// JS interop for crypto.subtle
// ---------------------------------------------------------------------------

@JS('crypto.subtle')
@staticInterop
class _SubtleCrypto {}

extension _SubtleCryptoExt on _SubtleCrypto {
  @JS('encrypt')
  external JSPromise<JSArrayBuffer> _encrypt(
    JSObject algorithm,
    JSObject key,
    JSArrayBuffer data,
  );

  @JS('decrypt')
  external JSPromise<JSArrayBuffer> _decrypt(
    JSObject algorithm,
    JSObject key,
    JSArrayBuffer data,
  );

  @JS('importKey')
  external JSPromise<JSObject> _importKey(
    JSString format,
    JSArrayBuffer keyData,
    JSObject algorithm,
    JSBoolean extractable,
    JSArray<JSAny?> keyUsages,
  );
}

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

/// AES-GCM 256 encryption via the browser's native WebCrypto.
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
/// Every call to [encrypt] generates a fresh random 12-byte IV via
/// `crypto.getRandomValues`. Re-using an IV with the same AES-GCM key
/// catastrophically breaks security — this class prevents that by design.
final class VaultCipher {
  /// AES-GCM IV length in bytes (96 bits, per NIST SP 800-38D §8.2.1).
  static const int ivLength = 12;

  /// GCM authentication tag length in bits (128 bits).
  static const int tagLength = 128;

  const VaultCipher();

  /// Encrypts [plaintext] with AES-256-GCM using a fresh random IV.
  ///
  /// Returns `(iv, ciphertext)` where:
  /// - [iv] is 12 random bytes (never reused)
  /// - [ciphertext] includes the 16-byte GCM authentication tag appended
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

    final subtle = _subtleCrypto;
    final effectiveIv = iv ?? _randomBytes(ivLength);

    final cryptoKey = await _importAesKey(subtle, key, 'encrypt');
    final algorithm = _aesGcmAlgorithm(effectiveIv,
        additionalData: additionalData);
    final data = (plaintext.buffer.toJS as JSArrayBuffer?)!;

    final resultBuffer = await subtle
        ._encrypt(algorithm, cryptoKey, data)
        .toDart;
    final ciphertext = resultBuffer.toDart.asUint8List();

    return (effectiveIv, ciphertext);
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

    final subtle = _subtleCrypto;
    final cryptoKey = await _importAesKey(subtle, key, 'decrypt');
    final algorithm = _aesGcmAlgorithm(iv, additionalData: additionalData);
    final data = (ciphertext.buffer.toJS as JSArrayBuffer?)!;
    try {
      final resultBuffer = await subtle
          ._decrypt(algorithm, cryptoKey, data)
          .toDart;
      return resultBuffer.toDart.asUint8List();
    } on Object {
      // WebCrypto throws an OperationError (DOMException) when GCM tag
      // validation fails. This surfaces as a Dart exception via the JS interop.
      throw const VaultCipherException(
        'Decryption failed: wrong key, tampered data, or corrupted ciphertext',
      );
    }
  }

  /// Generates a random 32-byte (256-bit) AES key via `crypto.getRandomValues`.
  static Uint8List generateKey() => _randomBytes(32);

  /// Generates [length] random bytes via `crypto.getRandomValues`.
  static Uint8List randomBytes(int length) => _randomBytes(length);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static _SubtleCrypto get _subtleCrypto {
    final crypto = globalContext['crypto']! as JSObject;
    return crypto['subtle']! as _SubtleCrypto;
  }

  static void _assertKeyLength(Uint8List key) {
    if (key.length != 32) {
      throw VaultCipherException(
        'AES-256 requires a 32-byte key, got ${key.length}',
      );
    }
  }

  static Future<JSObject> _importAesKey(
    _SubtleCrypto subtle,
    Uint8List keyBytes,
    String usage,
  ) async {
    final keyData = (keyBytes.buffer.toJS as JSArrayBuffer?)!;
    final algorithm = {
      'name': 'AES-GCM'.toJS,
    }.jsify()! as JSObject;
    final usages = [usage.toJS].toJS;
    final result = await subtle
        ._importKey(
          'raw'.toJS,
          keyData,
          algorithm,
          false.toJS,
          usages,
        )
        .toDart;
    return result;
  }

  static JSObject _aesGcmAlgorithm(Uint8List iv, {Uint8List? additionalData}) {
    final algo = <String, JSAny?>{
      'name': 'AES-GCM'.toJS,
      'iv': iv.toJS,
      'tagLength': tagLength.toJS,
    };
    if (additionalData != null) {
      algo['additionalData'] = additionalData.toJS;
    }
    return algo.jsify()! as JSObject;
  }
}

// ---------------------------------------------------------------------------
// Crypto-random bytes
// ---------------------------------------------------------------------------

/// Generates [length] cryptographically secure random bytes from the
/// browser's CSPRNG (`crypto.getRandomValues`).
///
/// Prefer [VaultCipher.randomBytes] or [VaultCipher.generateKey] for
/// convenience.
Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  final jsCrypto = globalContext['crypto']! as JSObject;
  final jsArray = bytes.toJS;
  jsCrypto.callMethod('getRandomValues'.toJS, jsArray);
  // Read back: on JS backend toDart is a cast (zero-copy); on Wasm it
  // unwraps the now-populated JSUint8Array back to a Uint8List.
  return jsArray.toDart;
}
