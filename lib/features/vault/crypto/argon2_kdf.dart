/// Concrete [VaultKdf] implementation backed by Argon2id from
/// package:cryptography.
///
/// Uses the `Argon2id(...)` factory, which dispatches to the best available
/// implementation per platform (same principle as [VaultCipher]'s
/// `AesGcm.with256bits()`). Parameters come from [Argon2Params].
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint the password or derived key.
/// - The [derive] method accepts and returns raw bytes — we intentionally
///   avoid the encoded-string API to skip superfluous encode/decode.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'vault_kdf.dart';

/// [VaultKdf] implementation using Argon2id from package:cryptography.
///
/// Pure-Dart implementation on every platform today; the factory leaves the
/// door open for a platform-accelerated implementation later without
/// touching vault_crypto/vault_envelope.
final class Argon2Kdf implements VaultKdf {
  const Argon2Kdf();

  /// Shared algorithm. Stateless — one instance serves all calls.
  static final Argon2id _argon2id = Argon2id(
    parallelism: Argon2Params.p,
    memory: Argon2Params.m,
    iterations: Argon2Params.t,
    hashLength: Argon2Params.hashLength,
  );

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    final key = await _argon2id.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}
