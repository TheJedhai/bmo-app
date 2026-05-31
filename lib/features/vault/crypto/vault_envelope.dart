/// Envelope encryption for the vault: DEK wrapping, recovery keys, and canary.
///
/// ## Architecture
/// ```
/// Password ──► Argon2id ──► KEK ──► AES-GCM ──► Wrapped DEK
///                                    ├──► Canary (password validator)
/// Recovery Key ──► AES-GCM ──► Recovery-Wrapped DEK (direct, no KDF)
/// ```
///
/// - **DEK** (Data Encryption Key): 32 random bytes. Encrypts all vault data.
/// - **KEK** (Key Encryption Key): 32 bytes derived from password + salt via
///   Argon2id. Wraps/unwraps the DEK.
/// - **Recovery Key**: 32 random bytes. Used directly as an AES-256 key to
///   wrap the DEK — no KDF, instant unlock. Shown to user once as base32/hex.
/// - **Canary**: A known constant encrypted with the KEK. Stored on the server
///   alongside the salt. Allows password validation (unlock) without downloading
///   the full vault.
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint keys, DEKs, recovery keys, or canary
///   plaintext.
/// - NEVER reuse an IV. Every wrap/canary operation generates a fresh IV.
/// - The recovery key is stored ONLY by the user. The server never sees it.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'vault_cipher.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Known plaintext encrypted to produce the canary.
/// Version-tagged so we can rotate the canary format if needed.
const _kCanaryPlaintext = 'BMO_VAULT_CANARY_V1';

/// Byte-length of the canary plaintext (for validation).
final _kCanaryBytes = utf8.encode(_kCanaryPlaintext);

// ---------------------------------------------------------------------------
// Envelope operations
// ---------------------------------------------------------------------------

/// Wraps (encrypts) a DEK with a KEK using AES-256-GCM.
///
/// Returns `(iv, wrappedDek)`:
/// - [iv]: 12 random bytes — store alongside the wrapped DEK.
/// - [wrappedDek]: AES-GCM ciphertext of the DEK (includes 16-byte GCM tag).
///
/// The caller MUST store both the iv and wrappedDek — both are needed for
/// [unwrapDek].
Future<(Uint8List, Uint8List)> wrapDek(
  Uint8List kek,
  Uint8List dek,
) async {
  final cipher = const VaultCipher();
  return cipher.encrypt(kek, dek);
}

/// Unwraps (decrypts) a DEK with a KEK.
///
/// Returns the 32-byte DEK.
///
/// Throws [VaultCipherException] if the KEK is wrong or the wrapped DEK has
/// been tampered with.
Future<Uint8List> unwrapDek(
  Uint8List kek,
  Uint8List iv,
  Uint8List wrappedDek,
) async {
  final cipher = const VaultCipher();
  return cipher.decrypt(kek, iv, wrappedDek);
}

// ---------------------------------------------------------------------------
// Canary (password validation without downloading vault)
// ---------------------------------------------------------------------------

/// Creates a canary: encrypts a known constant with the KEK.
///
/// Returns `(iv, canaryCiphertext)` to store on the server.
/// Used by [validateCanary] to verify the password on unlock.
Future<(Uint8List, Uint8List)> createCanary(Uint8List kek) async {
  final cipher = const VaultCipher();
  return cipher.encrypt(kek, Uint8List.fromList(_kCanaryBytes));
}

/// Validates a canary: decrypts with the KEK and checks the known constant.
///
/// Returns `true` if the password-derived KEK correctly decrypts the canary.
/// Returns `false` if decryption fails or the plaintext doesn't match.
///
/// This is the primary password validation mechanism — it works without
/// downloading the full vault from the server.
Future<bool> validateCanary(
  Uint8List kek,
  Uint8List iv,
  Uint8List canaryCiphertext,
) async {
  final cipher = const VaultCipher();
  try {
    final plaintext = await cipher.decrypt(kek, iv, canaryCiphertext);
    // Constant-time comparison to prevent timing side-channels on the
    // plaintext comparison (though GCM tag check already provides
    // strong protection).
    return _constantTimeEquals(plaintext, _kCanaryBytes);
  } on VaultCipherException {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Recovery key
// ---------------------------------------------------------------------------

/// Generates a 32-byte recovery key via CSPRNG.
///
/// The recovery key is an alternative AES-256 key that can unwrap the DEK
/// without the password. Show it to the user ONCE as a base32 or hex string.
///
/// The server stores `recoveryWrappedDek` (DEK encrypted with this key)
/// but never sees the recovery key itself.
Uint8List generateRecoveryKey() {
  return VaultCipher.generateKey();
}

/// Encodes a recovery key as a lowercase hex string (64 chars).
///
/// This is the user-facing format. Safe to display — but the user must
/// store it securely (password manager, printed copy, etc.).
String encodeRecoveryKey(Uint8List recoveryKey) {
  return _bytesToHex(recoveryKey);
}

/// Decodes a hex-encoded recovery key back to bytes.
///
/// Throws [FormatException] if the hex string is invalid.
Uint8List decodeRecoveryKey(String hexString) {
  if (hexString.length % 2 != 0) {
    throw FormatException('Hex string must have even length');
  }
  final bytes = Uint8List(hexString.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    final byteStr = hexString.substring(i * 2, i * 2 + 2);
    final byte = int.tryParse(byteStr, radix: 16);
    if (byte == null) {
      throw FormatException('Invalid hex character at position ${i * 2}');
    }
    bytes[i] = byte;
  }
  return bytes;
}

/// Wraps the DEK with a recovery key (direct AES-256-GCM, no KDF).
///
/// The recovery key is 32 random bytes used directly as an AES key.
/// Returns `(iv, wrappedDek)` to store on the server.
Future<(Uint8List, Uint8List)> wrapDekWithRecoveryKey(
  Uint8List recoveryKey,
  Uint8List dek,
) async {
  final cipher = const VaultCipher();
  return cipher.encrypt(recoveryKey, dek);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Constant-time byte comparison.
///
/// Always scans the entire length of both inputs (up to min length) to
/// prevent an attacker from measuring comparison time to learn byte-by-byte
/// differences.
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Converts bytes to lowercase hex string.
String _bytesToHex(List<int> bytes) {
  const hexChars = '0123456789abcdef';
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..write(hexChars[byte >> 4])
      ..write(hexChars[byte & 0x0F]);
  }
  return buffer.toString();
}
