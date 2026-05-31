/// Repository orchestrating vault create / unlock / recovery flows.
///
/// Connects the crypto core (Phase 8.1) to the bmo-server backend (Phase 8.0)
/// via [VaultClient]. Each method combines one or more HTTP calls with
/// client-side cryptographic operations.
///
/// ## Key material lifecycle
/// - The **DEK** lives only in memory — returned by unlock methods, consumed
///   by item encryption/decryption (Phase 8.3).
/// - The **recovery key** is shown once after [createVault] and optionally
///   re-displayed via [revealRecoveryKey]. NEVER persisted.
/// - The **KEK** lives in memory after a password unlock so that
///   [revealRecoveryKey] can re-display the recovery key without
///   re-deriving it.
///
/// ## Security rules (NEVER break these):
/// - NEVER log passwords, DEKs, KEKs, recovery keys, or plaintext.
/// - Recovery key and DEK live ONLY in memory.
library;

import 'dart:typed_data';

import '../crypto/vault_crypto.dart' as crypto;
import '../crypto/vault_envelope.dart';
import '../crypto/vault_kdf.dart';
import '../crypto/argon2_kdf.dart';
import 'vault_client.dart';
import 'vault_models.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Returned by [VaultRepository.createVault] — the server-created vault
/// metadata plus the one-time recovery key to display to the user.
final class VaultCreationResult {
  final Vault vault;

  /// 32-byte recovery key. Encode with [encodeRecoveryKey] for display
  /// (64 lowercase hex chars). **Show once, then discard.**
  final Uint8List recoveryKey;

  const VaultCreationResult({required this.vault, required this.recoveryKey});
}

/// Returned by [VaultRepository.unlockWithPassword].
///
/// Holds both the DEK (for item encryption) and the KEK (for
/// [VaultRepository.revealRecoveryKey]).
final class VaultUnlockResult {
  /// 32-byte Data Encryption Key — encrypts/decrypts vault items.
  final Uint8List dek;

  /// 32-byte Key Encryption Key — derived from password + salt via Argon2id.
  /// Keep in memory so [revealRecoveryKey] can decrypt the wrapped recovery
  /// key without re-deriving.
  final Uint8List kek;

  const VaultUnlockResult({required this.dek, required this.kek});
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final class VaultRepository {
  final VaultClient _client;
  final VaultKdf _kdf;

  VaultRepository(this._client, {VaultKdf? kdf})
      : _kdf = kdf ?? const Argon2Kdf();

  // ============================================================
  // Create
  // ============================================================

  /// Creates a new vault with the given [name] and [password].
  ///
  /// 1. Runs [crypto.createVault] from the crypto layer (salt, KEK, DEK,
  ///    wraps, canary, recovery key).
  /// 2. POSTs the server-safe material to the backend.
  /// 3. Returns the created [Vault] metadata plus the one-time [recoveryKey].
  ///
  /// The caller MUST display the recovery key to the user once and then
  /// discard it — it is NEVER persisted.
  Future<VaultCreationResult> createVault(
    String name,
    String password,
  ) async {
    final material = await crypto.createVault(password, kdf: _kdf);
    final vault = await _client.createVault(name: name, material: material);
    return VaultCreationResult(vault: vault, recoveryKey: material.recoveryKey);
  }

  // ============================================================
  // Unlock — password
  // ============================================================

  /// Unlocks a vault with a password.
  ///
  /// 1. Fetches key material from `GET /vaults/{vaultId}/keys`.
  /// 2. Derives KEK from password + salt (Argon2id).
  /// 3. Validates the canary — throws [WrongPasswordException] on mismatch.
  /// 4. Unwraps the DEK with the KEK.
  ///
  /// Returns both the DEK (for item operations) and the KEK (so that
  /// [revealRecoveryKey] can be called later without re-deriving).
  ///
  /// Throws [VaultApiException] on HTTP errors.
  /// Throws [crypto.WrongPasswordException] if the password is incorrect.
  Future<VaultUnlockResult> unlockWithPassword(
    String vaultId,
    String password,
  ) async {
    final material = await _client.getKeys(vaultId);

    // Derive KEK (same as crypto.unlock but we need to capture the KEK)
    final passwordBytes = Uint8List.fromList(password.codeUnits);
    final kek = await _kdf.derive(
      password: passwordBytes,
      salt: material.salt,
    );

    // Validate canary
    final canaryOk = await validateCanary(
      kek,
      material.canaryIv,
      material.canaryCiphertext,
    );
    if (!canaryOk) {
      throw const crypto.WrongPasswordException();
    }

    // Unwrap DEK
    final dek = await unwrapDek(kek, material.dekIv, material.wrappedDek);

    return VaultUnlockResult(dek: dek, kek: kek);
  }

  // ============================================================
  // Unlock — recovery key
  // ============================================================

  /// Unlocks a vault using the recovery key instead of a password.
  ///
  /// 1. Fetches key material from `GET /vaults/{vaultId}/keys`.
  /// 2. Unwraps the DEK directly with the recovery key (no KDF).
  ///
  /// Returns the 32-byte DEK.
  ///
  /// Throws [VaultApiException] on HTTP errors.
  /// Throws [VaultCipherException] if the recovery key is wrong.
  Future<Uint8List> unlockWithRecoveryKey(
    String vaultId,
    Uint8List recoveryKey,
  ) async {
    final material = await _client.getKeys(vaultId);
    return crypto.unlockWithRecoveryKey(recoveryKey, material);
  }

  // ============================================================
  // Recovery key re-display
  // ============================================================

  /// Reveals the recovery key using the [kek] from a prior password unlock.
  ///
  /// 1. Fetches key material from `GET /vaults/{vaultId}/keys`.
  /// 2. Decrypts `recovery_key_wrapped` with the KEK.
  /// 3. Returns the 32-byte recovery key in plaintext.
  ///
  /// [kek] must be the KEK returned by [unlockWithPassword]. Passing a DEK
  /// instead will fail — the recovery key is wrapped with the KEK, not the DEK.
  ///
  /// **NEVER persist or log the returned key.**
  ///
  /// Throws [VaultApiException] on HTTP errors.
  /// Throws [VaultCipherException] if the KEK is wrong.
  Future<Uint8List> revealRecoveryKey(
    String vaultId,
    Uint8List kek,
  ) async {
    final material = await _client.getKeys(vaultId);
    return crypto.revealRecoveryKey(material, kek);
  }

  // ============================================================
  // Verify recovery key (without unlocking)
  // ============================================================

  /// Verifies that a user-supplied recovery key truly unwraps the DEK.
  ///
  /// Does NOT return the DEK — only proves the key is correct.
  /// Use this to confirm a recovery key before using it for unlock.
  ///
  /// Performs the actual GCM unwrap (not string comparison).
  Future<bool> verifyRecoveryKey(
    String vaultId,
    Uint8List recoveryKey,
  ) async {
    final material = await _client.getKeys(vaultId);
    return crypto.verifyRecoveryKeyUnlocks(material, recoveryKey);
  }

  // ============================================================
  // Vault management
  // ============================================================

  /// Lists all vaults for the current agent.
  Future<List<Vault>> listVaults() => _client.listVaults();

  /// Fetches metadata for a single vault.
  Future<Vault> getVault(String id) => _client.getVault(id);

  /// Deletes a vault and all its encrypted data.
  ///
  /// **Destructive.** The caller should confirm with the user first.
  Future<void> deleteVault(String id) => _client.deleteVault(id);
}
