/// Vault creation and unlocking — ties KDF, cipher, and envelope together.
///
/// These are the primary operations exposed to the rest of the app:
/// - [createVault]: called once when a user first creates a vault.
///   Produces all material needed for `POST /api/v1/vaults`.
/// - [unlock]: called every time the user unlocks their vault.
///   Takes password + server material from `GET /vaults/{id}/keys`,
///   validates the canary, and returns the DEK.
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint passwords, DEKs, recovery keys, or
///   any key material.
/// - The DEK stays in memory ONLY — never written to disk, never sent
///   to the server in plaintext.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'argon2_kdf.dart';
import 'vault_cipher.dart';
import 'vault_envelope.dart';
import 'vault_kdf.dart';

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

/// Material produced by [createVault], ready to send to the server.
///
/// Every field goes in the POST /api/v1/vaults body. The recovery wraps are
/// generated on purpose (see [createVault]) — stored server-side as an inert
/// fallback net, nothing consumes them.
final class VaultCreationMaterial {
  const VaultCreationMaterial({
    required this.salt,
    required this.wrappedDek,
    required this.dekIv,
    required this.canaryCiphertext,
    required this.canaryIv,
    required this.recoveryWrappedDek,
    required this.recoveryDekIv,
    required this.recoveryKeyWrapped,
    required this.recoveryKeyWrapIv,
    required this.nameBlob,
    required this.nameIv,
  });

  /// 16-byte random salt for Argon2id KEK derivation.
  final Uint8List salt;

  /// DEK encrypted with KEK (AES-256-GCM, includes 16-byte GCM tag).
  final Uint8List wrappedDek;

  /// 12-byte random IV for [wrappedDek].
  final Uint8List dekIv;

  /// Known constant encrypted with KEK (AES-256-GCM, includes GCM tag).
  final Uint8List canaryCiphertext;

  /// 12-byte random IV for [canaryCiphertext].
  final Uint8List canaryIv;

  /// DEK encrypted with recovery key (AES-256-GCM, includes GCM tag).
  final Uint8List recoveryWrappedDek;

  /// 12-byte random IV for [recoveryWrappedDek].
  final Uint8List recoveryDekIv;

  /// Recovery key encrypted with KEK (AES-256-GCM, includes GCM tag).
  final Uint8List recoveryKeyWrapped;

  /// 12-byte random IV for [recoveryKeyWrapped].
  final Uint8List recoveryKeyWrapIv;

  /// Vault name encrypted with KEK (AES-256-GCM, includes 16-byte GCM tag).
  /// Stored server-side so the name can only be read after password unlock.
  final Uint8List nameBlob;

  /// 12-byte random IV for [nameBlob].
  final Uint8List nameIv;

  // -------------------------------------------------------------------------
  // JSON serialization (base64 for binary fields)
  // -------------------------------------------------------------------------

  /// Serializes all fields to a JSON-ready map.
  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'wrapped_dek': base64Encode(wrappedDek),
        'dek_iv': base64Encode(dekIv),
        'canary_ciphertext': base64Encode(canaryCiphertext),
        'canary_iv': base64Encode(canaryIv),
        'recovery_wrapped_dek': base64Encode(recoveryWrappedDek),
        'recovery_dek_iv': base64Encode(recoveryDekIv),
        'recovery_key_wrapped': base64Encode(recoveryKeyWrapped),
        'recovery_key_wrap_iv': base64Encode(recoveryKeyWrapIv),
        'name_blob': base64Encode(nameBlob),
        'name_iv': base64Encode(nameIv),
      };
}

/// Material fetched from the server to unlock a vault.
///
/// All fields come from `GET /vaults/{id}/keys`.
final class VaultUnlockMaterial {
  const VaultUnlockMaterial({
    required this.salt,
    required this.wrappedDek,
    required this.dekIv,
    required this.canaryCiphertext,
    required this.canaryIv,
    required this.recoveryWrappedDek,
    required this.recoveryDekIv,
    required this.recoveryKeyWrapped,
    required this.recoveryKeyWrapIv,
    required this.nameBlob,
    required this.nameIv,
  });

  final Uint8List salt;
  final Uint8List wrappedDek;
  final Uint8List dekIv;
  final Uint8List canaryCiphertext;
  final Uint8List canaryIv;
  final Uint8List recoveryWrappedDek;
  final Uint8List recoveryDekIv;

  /// Recovery key encrypted with KEK. Retrieved from the server but not
  /// consumed — kept as an inert fallback envelope.
  final Uint8List recoveryKeyWrapped;

  /// 12-byte random IV for [recoveryKeyWrapped].
  final Uint8List recoveryKeyWrapIv;

  /// Vault name encrypted with KEK (AES-256-GCM).
  /// Decrypt with the KEK after a successful password unlock.
  final Uint8List nameBlob;

  /// 12-byte random IV for [nameBlob].
  final Uint8List nameIv;

  // -------------------------------------------------------------------------
  // JSON deserialization (base64 for binary fields)
  // -------------------------------------------------------------------------

  factory VaultUnlockMaterial.fromJson(Map<String, dynamic> json) {
    return VaultUnlockMaterial(
      salt: base64Decode(json['salt'] as String? ?? ''),
      wrappedDek: base64Decode(json['wrapped_dek'] as String? ?? ''),
      dekIv: base64Decode(json['dek_iv'] as String? ?? ''),
      canaryCiphertext:
          base64Decode(json['canary_ciphertext'] as String? ?? ''),
      canaryIv: base64Decode(json['canary_iv'] as String? ?? ''),
      recoveryWrappedDek:
          base64Decode(json['recovery_wrapped_dek'] as String? ?? ''),
      recoveryDekIv: base64Decode(json['recovery_dek_iv'] as String? ?? ''),
      recoveryKeyWrapped:
          base64Decode(json['recovery_key_wrapped'] as String? ?? ''),
      recoveryKeyWrapIv:
          base64Decode(json['recovery_key_wrap_iv'] as String? ?? ''),
      nameBlob: base64Decode(json['name_blob'] as String? ?? ''),
      nameIv: base64Decode(json['name_iv'] as String? ?? ''),
    );
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Creates a new vault from a user's [password] and [name].
///
/// Generates:
/// - A random 16-byte salt
/// - A random 32-byte DEK (the actual data encryption key)
/// - KEK derived from password + salt via Argon2id
/// - Wrapped DEK (DEK encrypted with KEK)
/// - Recovery-wrapped DEK + wrapped recovery key (see note below)
/// - Canary (known constant encrypted with KEK) for password validation
/// - Encrypted name (name encrypted with KEK)
///
/// [kdf] allows injection of a mock for testing.
Future<VaultCreationMaterial> createVault(
  String password,
  String name, {
  VaultKdf? kdf,
}) async {
  final effectiveKdf = kdf ?? const Argon2Kdf();

  // 1. Generate salt
  final salt = VaultCipher.randomBytes(Argon2Params.saltLength);

  // 2. Derive KEK from password + salt
  final passwordBytes = Uint8List.fromList(password.codeUnits);
  final kek = await effectiveKdf.derive(
    password: passwordBytes,
    salt: salt,
  );

  // 3. Generate DEK
  final dek = VaultCipher.generateKey();

  // 4. Wrap DEK with KEK
  final (dekIv, wrappedDek) = await wrapDek(kek, dek);

  // 5. Create canary
  final (canaryIv, canaryCiphertext) = await createCanary(kek);

  // The recovery wraps below are generated ON PURPOSE and sent to the
  // server, where they stay inert. Consumption (unlock/reveal by recovery
  // key) was removed; the envelopes are the only fallback net until the
  // master password feature ships. The plaintext recovery key is discarded
  // after creation.
  final recoveryKey = generateRecoveryKey();

  // 6. Wrap recovery key with KEK
  final (recoveryKeyWrapIv, recoveryKeyWrapped) = await _wrapRecoveryKey(
    kek,
    recoveryKey,
  );

  // 7. Wrap DEK with recovery key
  final (recoveryDekIv, recoveryWrappedDek) =
      await wrapDekWithRecoveryKey(recoveryKey, dek);

  // 8. Encrypt vault name with KEK
  final nameBytes = Uint8List.fromList(name.codeUnits);
  final (nameIv, nameBlob) = await _encryptName(kek, nameBytes);

  return VaultCreationMaterial(
    salt: salt,
    wrappedDek: wrappedDek,
    dekIv: dekIv,
    canaryCiphertext: canaryCiphertext,
    canaryIv: canaryIv,
    recoveryWrappedDek: recoveryWrappedDek,
    recoveryDekIv: recoveryDekIv,
    recoveryKeyWrapped: recoveryKeyWrapped,
    recoveryKeyWrapIv: recoveryKeyWrapIv,
    nameBlob: nameBlob,
    nameIv: nameIv,
  );
}

/// Unlocks a vault using a [password] and server-provided [material].
///
/// Steps:
/// 1. Derive KEK from password + salt (Argon2id)
/// 2. Validate canary — if this fails, the password is wrong
/// 3. Unwrap DEK with KEK
///
/// Returns the 32-byte DEK on success.
///
/// Throws [VaultCipherException] if decryption fails.
/// Throws [WrongPasswordException] if the canary doesn't validate.
///
/// [kdf] allows injection of a mock for testing.
Future<Uint8List> unlock(
  String password,
  VaultUnlockMaterial material, {
  VaultKdf? kdf,
}) async {
  final effectiveKdf = kdf ?? const Argon2Kdf();

  // 1. Derive KEK
  final passwordBytes = Uint8List.fromList(password.codeUnits);
  final kek = await effectiveKdf.derive(
    password: passwordBytes,
    salt: material.salt,
  );

  // 2. Validate canary
  final canaryOk = await validateCanary(
    kek,
    material.canaryIv,
    material.canaryCiphertext,
  );
  if (!canaryOk) {
    throw const WrongPasswordException();
  }

  // 3. Unwrap DEK
  return unwrapDek(kek, material.dekIv, material.wrappedDek);
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

/// Wraps (encrypts) the recovery key with the KEK so it can be stored on
/// the server as an inert envelope.
Future<(Uint8List, Uint8List)> _wrapRecoveryKey(
  Uint8List kek,
  Uint8List recoveryKey,
) async {
  final cipher = const VaultCipher();
  return cipher.encrypt(kek, recoveryKey);
}

/// Encrypts the vault name with the KEK.
///
/// Returns `(iv, nameBlob)` where nameBlob is the AES-256-GCM ciphertext
/// (includes 16-byte GCM tag) of the UTF-8 encoded name.
Future<(Uint8List, Uint8List)> _encryptName(
  Uint8List kek,
  Uint8List nameBytes,
) async {
  final cipher = const VaultCipher();
  return cipher.encrypt(kek, nameBytes);
}

/// Decrypts the vault name with the KEK.
///
/// Returns the decrypted name bytes (UTF-8 encoded).
/// Caller should decode with [String.fromCharCodes] to get the plaintext name.
///
/// Throws [VaultCipherException] if the KEK is wrong or the name blob has
/// been tampered with.
Future<String> decryptName(
  Uint8List kek,
  Uint8List nameIv,
  Uint8List nameBlob,
) async {
  final cipher = const VaultCipher();
  final nameBytes = await cipher.decrypt(kek, nameIv, nameBlob);
  return String.fromCharCodes(nameBytes);
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown by [unlock] when the password-derived KEK doesn't decrypt the
/// canary (wrong password).
final class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'WrongPasswordException: invalid password';
}
