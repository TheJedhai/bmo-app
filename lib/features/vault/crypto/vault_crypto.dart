/// Vault creation and unlocking — ties KDF, cipher, and envelope together.
///
/// These are the two primary operations exposed to the rest of the app:
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
/// - After [createVault], the recovery key is shown to the user ONCE.
///   The app MUST NOT store it.
library;

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
final class VaultCreationMaterial {
  const VaultCreationMaterial({
    required this.salt,
    required this.wrappedDek,
    required this.dekIv,
    required this.canaryCiphertext,
    required this.canaryIv,
    required this.recoveryWrappedDek,
    required this.recoveryDekIv,
    required this.recoveryKey,
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

  /// 32-byte recovery key. **Show to the user ONCE, then discard it.**
  /// Encode with [encodeRecoveryKey] to display as 64 hex chars.
  final Uint8List recoveryKey;
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
  });

  final Uint8List salt;
  final Uint8List wrappedDek;
  final Uint8List dekIv;
  final Uint8List canaryCiphertext;
  final Uint8List canaryIv;
  final Uint8List recoveryWrappedDek;
  final Uint8List recoveryDekIv;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Creates a new vault from a user's [password].
///
/// Generates:
/// - A random 16-byte salt
/// - A random 32-byte DEK (the actual data encryption key)
/// - A random 32-byte recovery key
/// - KEK derived from password + salt via Argon2id
/// - Wrapped DEK (DEK encrypted with KEK)
/// - Recovery-wrapped DEK (DEK encrypted with recovery key)
/// - Canary (known constant encrypted with KEK) for password validation
///
/// Returns [VaultCreationMaterial] with everything the server needs
/// PLUS the recovery key (shown to user once, NEVER sent to server).
///
/// [kdf] allows injection of a mock for testing.
Future<VaultCreationMaterial> createVault(
  String password, {
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

  // 6. Wrap DEK with recovery key
  final (recoveryDekIv, recoveryWrappedDek) =
      await wrapDekWithRecoveryKey(recoveryKey, dek);

  return VaultCreationMaterial(
    salt: salt,
    wrappedDek: wrappedDek,
    dekIv: dekIv,
    canaryCiphertext: canaryCiphertext,
    canaryIv: canaryIv,
    recoveryWrappedDek: recoveryWrappedDek,
    recoveryDekIv: recoveryDekIv,
    recoveryKey: recoveryKey,
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
