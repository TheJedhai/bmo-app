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
/// Deliberately BELOW OWASP recommendations. Do NOT "fix" this back up:
///
/// - Threat model: personal vault behind Tailscale, never publicly exposed.
///   Offline brute-force resistance is not a requirement — the password
///   only protects against casual glance.
/// - Cost: Argon2 runs pure-Dart on the browser main thread (no isolate),
///   and OWASP-scale parameters took ~5 s per derivation on web.
///
/// - **m = 4096 KiB** (4 MiB) — keeps derivation interactive.
/// - **t = 3** — iteration count (time cost).
/// - **p = 1** — parallelism. Single-threaded in the browser;
///   increasing would multiply memory usage (m * p) without benefit.
library;

import 'dart:typed_data';

/// Named Argon2id parameters used for KEK derivation.
///
/// Adjust these if security requirements or UX constraints change.
/// All values follow the naming conventions from RFC 9106.
abstract final class Argon2Params {
  /// Memory size in kibibytes (1024 bytes).
  /// Tuned for interactive web derivation (see library doc).
  static const int m = 4096;

  /// Number of iterations (time cost).
  static const int t = 3;

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
