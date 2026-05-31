/// Vault KDF (Key Derivation Function) interface.
///
/// Isolated behind an abstract interface so the underlying Argon2
/// implementation can be swapped without touching cipher/envelope code.
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint the password, salt, or derived key.
/// - NEVER store the password or derived key outside memory.
/// - The salt MUST be unique per vault (16+ bytes from CSPRNG).
///
/// ## Argon2id parameters
/// Chosen per OWASP recommendations for server-side password hashing,
/// applied here to client-side KEK derivation:
///
/// - **m = 19456 KiB** (~19 MiB) — memory-hardness to deter GPU/ASIC attacks.
///   On the client this also provides a UX-level brute-force throttle.
/// - **t = 2** — iteration count (time cost). Kept low because memory
///   hardness already dominates the cost; raising t hurts mobile UX.
/// - **p = 1** — parallelism. Single-threaded in the browser;
///   increasing would multiply memory usage (m * p) without benefit.
///
/// These constants are easy to adjust if OWASP updates recommendations
/// or if UX testing finds the derivation too slow on low-end devices.
library;

import 'dart:typed_data';

/// Named Argon2id parameters used for KEK derivation.
///
/// Adjust these if security requirements or UX constraints change.
/// All values follow the naming conventions from RFC 9106.
abstract final class Argon2Params {
  /// Memory size in kibibytes (1024 bytes).
  /// OWASP 2023 recommends 19 MiB = 19456 KiB.
  static const int m = 19456;

  /// Number of iterations (time cost).
  static const int t = 2;

  /// Degree of parallelism (lanes).
  /// Keep at 1 for web — browser main thread is single-threaded.
  static const int p = 1;

  /// Output key length in bytes (32 = 256-bit KEK).
  static const int hashLength = 32;

  /// Salt length in bytes (16 = 128-bit).
  static const int saltLength = 16;
}

/// Abstract interface for password-based key derivation.
///
/// The vault uses this to derive a KEK (Key Encryption Key) from the
/// user's password and a random salt. The KEK is then used to wrap/unwrap
/// the DEK (Data Encryption Key) via AES-GCM.
abstract class VaultKdf {
  /// Derives a fixed-length key from [password] and [salt].
  ///
  /// Both [password] and [salt] are arbitrary byte sequences.
  /// Returns exactly [Argon2Params.hashLength] bytes (32).
  ///
  /// The caller is responsible for zeroing [password] after use.
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  });
}

/// Thrown when the KDF cannot operate because the hash-wasm WASM module
/// is not loaded.
///
/// This is a **visible failure** — it prevents the vault from silently
/// falling back to a CDN import. If you see this, the self-hosted
/// `web/hash-wasm/index.esm.js` failed to load and the vault cannot
/// derive keys until the underlying issue is resolved.
///
/// This exception is part of **Camada 1** of the CDN-fallback defense.
/// Camada 2 (failsafe stub in `web/index.html`) ensures that dargon2
/// never sees `window.hashwasm` as null, preventing the CDN import
/// from ever being triggered.
final class VaultKdfUnavailableException implements Exception {
  const VaultKdfUnavailableException();

  @override
  String toString() =>
    'VaultKdfUnavailableException: hash-wasm WASM module not loaded. '
    'The self-hosted web/hash-wasm/index.esm.js failed to initialize. '
    'The vault cannot derive keys until this is resolved. '
    'Verify that web/hash-wasm/index.esm.js exists and is served correctly.';
}
