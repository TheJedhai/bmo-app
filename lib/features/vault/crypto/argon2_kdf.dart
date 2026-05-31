/// Concrete [VaultKdf] implementation backed by dargon2_flutter.
///
/// On web, dargon2 delegates to hash-wasm (WASM), which is pre-loaded
/// from a local asset (see web/index.html). No CDN calls at runtime.
///
/// ## CDN fallback defense (Camada 1)
/// Before calling into dargon2, [derive] checks that `window.hashwasm` is
/// populated. If the self-hosted WASM failed to load, this throws
/// [VaultKdfUnavailableException] instead of letting dargon2 silently
/// fall back to `import("cdn.jsdelivr.net/...")`.
///
/// Camada 2 (failsafe stub in `web/index.html`) ensures that
/// `window.hashwasm` is NEVER null — even if the ESM import fails —
/// so dargon2's `_registerDependency()` always finds it populated
/// and never triggers the CDN path.
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint the password or derived key.
/// - The [derive] method accepts and returns raw bytes — we intentionally
///   avoid the encoded-string API to skip superfluous encode/decode.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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
    // Camada 1: verify the self-hosted WASM module is available.
    // This check reads `window.hashwasm` — it does NOT trigger any
    // dargon2 initialization or CDN import. If hashwasm is missing,
    // we fail loudly instead of letting dargon2 silently fetch from CDN.
    if (globalContext['hashwasm'] == null) {
      throw const VaultKdfUnavailableException();
    }

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
