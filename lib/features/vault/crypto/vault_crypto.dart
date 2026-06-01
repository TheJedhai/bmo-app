/// Vault creation and unlocking — ties KDF, cipher, and envelope together.
///
/// These are the primary operations exposed to the rest of the app:
/// - [createVault]: called once when a user first creates a vault.
///   Produces all material needed for `POST /api/v1/vaults`.
/// - [unlock]: called every time the user unlocks their vault.
///   Takes password + server material from `GET /vaults/{id}/keys`,
///   validates the canary, and returns the DEK.
/// - [unlockWithRecoveryKey]: unlock using the recovery key instead of password.
/// - [revealRecoveryKey]: with the vault already unlocked (KEK in memory),
///   decrypts the wrapped recovery key for re-display.
/// - [verifyRecoveryKeyUnlocks]: proves a user-supplied recovery key truly
///   unwraps the DEK (does NOT compare strings — performs the actual unwrap).
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint passwords, DEKs, recovery keys, or
///   any key material.
/// - The DEK stays in memory ONLY — never written to disk, never sent
///   to the server in plaintext.
/// - After [createVault], the recovery key is shown to the user ONCE.
///   The app MUST NOT store it.
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
/// All fields except [recoveryKey] go in the POST /api/v1/vaults body.
/// [recoveryKey] is shown to the user once and NEVER sent to the server.
///
/// [recoveryKeyWrapped] is the recovery key encrypted with the KEK — stored
/// on the server so that [revealRecoveryKey] can re-display it later.
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
    required this.recoveryKey,
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
  /// Stored server-side so [revealRecoveryKey] can re-display it.
  final Uint8List recoveryKeyWrapped;

  /// 12-byte random IV for [recoveryKeyWrapped].
  final Uint8List recoveryKeyWrapIv;

  /// 32-byte recovery key. **Show to the user ONCE, then discard it.**
  /// Encode with [encodeRecoveryKey] to display as 64 hex chars.
  final Uint8List recoveryKey;

  /// Vault name encrypted with KEK (AES-256-GCM, includes 16-byte GCM tag).
  /// Stored server-side so the name can only be read after password unlock.
  final Uint8List nameBlob;

  /// 12-byte random IV for [nameBlob].
  final Uint8List nameIv;

  // -------------------------------------------------------------------------
  // JSON serialization (base64 for binary fields)
  // -------------------------------------------------------------------------

  /// Serializes all server-safe fields to a JSON-ready map.
  ///
  /// **IMPORTANT:** [recoveryKey] is deliberately excluded — it must NEVER
  /// be sent to the server.
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

  /// Recovery key encrypted with KEK. Retrieved from the server for
  /// [revealRecoveryKey] to re-display the recovery key.
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
/// - A random 32-byte recovery key
/// - KEK derived from password + salt via Argon2id
/// - Wrapped DEK (DEK encrypted with KEK)
/// - Recovery-wrapped DEK (DEK encrypted with recovery key)
/// - Wrapped recovery key (recovery key encrypted with KEK) for re-display
/// - Canary (known constant encrypted with KEK) for password validation
/// - Encrypted name (name encrypted with KEK)
///
/// Returns [VaultCreationMaterial] with everything the server needs
/// PLUS the recovery key (shown to user once, NEVER sent to server).
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

  // 3. Generate DEK and recovery key
  final dek = VaultCipher.generateKey();
  final recoveryKey = generateRecoveryKey();

  // 4. Wrap DEK with KEK
  final (dekIv, wrappedDek) = await wrapDek(kek, dek);

  // 5. Create canary
  final (canaryIv, canaryCiphertext) = await createCanary(kek);

  // 6. Wrap recovery key with KEK (for re-display via revealRecoveryKey)
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
    recoveryKey: recoveryKey,
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

/// Unlocks a vault using a [recoveryKey] instead of a password.
///
/// No KDF — the recovery key IS the AES-256 key. Instant unlock.
///
/// Returns the 32-byte DEK on success.
///
/// Throws [VaultCipherException] if the recovery key is wrong
/// or the wrapped DEK has been tampered with.
Future<Uint8List> unlockWithRecoveryKey(
  Uint8List recoveryKey,
  VaultUnlockMaterial material,
) async {
  return unwrapDek(
    recoveryKey,
    material.recoveryDekIv,
    material.recoveryWrappedDek,
  );
}

/// Reveals the recovery key by decrypting [material.recoveryKeyWrapped] with
/// the [kek] (which must already be derived from a successful password unlock).
///
/// The caller is responsible for deriving the KEK first — typically the
/// repository derives it during [unlock] and keeps it in memory for this call.
///
/// Returns the 32-byte recovery key in plaintext.
///
/// **NEVER persist or log the returned key.** It is for one-time display only.
///
/// Throws [VaultCipherException] if decryption fails (should not happen with
/// a valid KEK from a successful unlock).
Future<Uint8List> revealRecoveryKey(
  VaultUnlockMaterial material,
  Uint8List kek,
) async {
  final cipher = const VaultCipher();
  return cipher.decrypt(kek, material.recoveryKeyWrapIv,
      material.recoveryKeyWrapped);
}

/// Verifies that [recoveryKey] truly unwraps the DEK.
///
/// Performs the actual unwrap of [material.recoveryWrappedDek] using the
/// provided [recoveryKey] and validates the result by re-wrapping with
/// the KEK-wrapped DEK. Returns `true` if the key works, `false` otherwise.
///
/// This is cryptographically sound — it does NOT compare plaintext strings.
/// If GCM decryption succeeds, the key is correct; if it throws, the key
/// is wrong.
///
/// Prefer this over string comparison of recovery keys. String comparison
/// creates a side-channel risk and fails if the user copies with different
/// formatting (whitespace, dashes, case).
Future<bool> verifyRecoveryKeyUnlocks(
  VaultUnlockMaterial material,
  Uint8List recoveryKey,
) async {
  try {
    await unwrapDek(
      recoveryKey,
      material.recoveryDekIv,
      material.recoveryWrappedDek,
    );
    return true;
  } on VaultCipherException {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

/// Wraps (encrypts) the recovery key with the KEK so it can be stored on
/// the server and re-displayed later via [revealRecoveryKey].
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
