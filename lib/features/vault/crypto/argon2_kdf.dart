/// Concrete [VaultKdf] implementation backed by dargon2_flutter.
///
/// On web, dargon2 delegates to hash-wasm (WASM), which is pre-loaded
/// from a local asset (see web/index.html). No CDN calls at runtime.
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint the password or derived key.
/// - The [derive] method accepts and returns raw bytes — we intentionally
///   avoid the encoded-string API to skip superfluous encode/decode.
library;

import 'dart:typed_data';

import 'package:dargon2_flutter/dargon2_flutter.dart';

import 'vault_kdf.dart';

/// [VaultKdf] implementation using dargon2_flutter (WASM hash-wasm).
///
/// Uses the byte-level API (`hashPasswordBytes`) to avoid the
/// encode/decode overhead of the string-based `hashPasswordString`.
final class Argon2Kdf implements VaultKdf {
  const Argon2Kdf();

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    final result = await argon2.hashPasswordBytes(
      password.toList(),
      salt: Salt(salt.toList()),
      iterations: Argon2Params.t,
      memory: Argon2Params.m,
      parallelism: Argon2Params.p,
      length: Argon2Params.hashLength,
      type: Argon2Type.id,
    );
    return Uint8List.fromList(result.rawBytes);
  }
}
