/// Vault feature providers — client, repository, and in-memory session.
///
/// ## Security: DEK and KEK live ONLY in memory
///
/// The [vaultSessionProvider] holds the DEK, KEK, and decrypted vault name
/// in a pure-Dart [VaultSession] object. These values are **never** written
/// to localStorage, SharedPreferences, IndexedDB, or any persistent storage.
///
/// - **Reloading the page = vault locked.** There is no way to recover the
///   session from storage because it was never stored.
/// - **Switching tabs locks the vault** because [AppTab.vault] has
///   `keepAlive: false` — the TabPage is disposed, the provider goes with it.
/// - Phase 8.4 will add an inactivity timer that calls [VaultSessionNotifier.lock]
///   to proactively zero the keys even while the tab is open.
///
/// **NEVER log, print, or debugPrint the DEK, KEK, password, recovery key,
/// or decrypted name.**
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../crypto/vault_crypto.dart' as crypto;
import '../crypto/vault_envelope.dart';
import '../data/vault_client.dart';
import '../data/vault_repository.dart';

// ============================================================
// Infraestrutura
// ============================================================

/// Provides the [VaultClient] for HTTP communication with bmo-server.
final vaultClientProvider = Provider<VaultClient>((ref) {
  return VaultClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

/// Provides the [VaultRepository] that orchestrates crypto + HTTP.
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(ref.read(vaultClientProvider));
});

// ============================================================
// Session (in-memory only — NEVER persisted)
// ============================================================

/// The unlocked vault session — holds all key material in memory.
///
/// All fields are **volatile** and **never persisted**. This object is
/// created by a successful password or recovery-key unlock, and destroyed
/// by [VaultSessionNotifier.lock] or when the widget tree disposes.
final class VaultSession {
  /// Server-assigned vault ID.
  final String vaultId;

  /// 32-byte Data Encryption Key — encrypts/decrypts vault items.
  final Uint8List dek;

  /// 32-byte Key Encryption Key — derived from password via Argon2id.
  /// Used to re-display the recovery key via [VaultRepository.revealRecoveryKey].
  /// May be absent when unlocked via recovery key (no KDF in that path).
  final Uint8List? kek;

  /// The vault name, decrypted from the server's name_blob.
  /// **NEVER persist or log.**
  final String decryptedName;

  const VaultSession({
    required this.vaultId,
    required this.dek,
    this.kek,
    required this.decryptedName,
  });
}

/// The single source of truth for vault locked/unlocked state.
///
/// - `null` → locked (show unlock screen or "create first vault").
/// - [VaultSession] → unlocked (show vault contents).
///
/// Created via [VaultSessionNotifier.new] and accessed via
/// `ref.watch(vaultSessionProvider)`.
final vaultSessionProvider =
    NotifierProvider<VaultSessionNotifier, VaultSession?>(
  VaultSessionNotifier.new,
);

/// Manages the in-memory [VaultSession].
///
/// When [state] is `null`, the vault is **locked** — the UI shows the
/// unlock screen. When [state] is a [VaultSession], the vault is **open**
/// and the UI shows the vault contents.
///
/// ## Lifecycle
/// - Created by [unlockWithPassword] or [unlockWithRecoveryKey].
/// - Destroyed by [lock] or by widget disposal (keepAlive: false on the tab).
/// - Phase 8.4 will add an inactivity timer that calls [lock] automatically.
///
/// **NEVER call [lock] from [build]** — it would cause an infinite loop.
/// Only call it from user actions (tap "Travar") or timers.
final class VaultSessionNotifier extends Notifier<VaultSession?> {
  @override
  VaultSession? build() => null;

  /// Unlocks the vault with a password.
  ///
  /// 1. Fetches unlock material for ALL vaults from the server.
  /// 2. Tests [password] against each vault's canary.
  /// 3. The first vault whose canary validates is the one we open.
  /// 4. Fetches full key material for that vault.
  /// 5. Decrypts the vault name and sets the session.
  ///
  /// Throws [crypto.WrongPasswordException] if no canary validates.
  /// Throws [VaultApiException] on HTTP errors.
  Future<void> unlockWithPassword(String password) async {
    final repo = ref.read(vaultRepositoryProvider);

    // 1. Get all unlock materials (salt + canary per vault).
    final lookups = await repo.listUnlockMaterials();

    if (lookups.isEmpty) {
      // No vaults exist — signal to the UI to show "create first vault".
      throw const NoVaultsException();
    }

    // 2. Test password against each vault's canary.
    String? matchedVaultId;
    for (final lookup in lookups) {
      final ok = await repo.testCanary(
        password: password,
        salt: lookup.material.salt,
        canaryIv: lookup.material.canaryIv,
        canaryCiphertext: lookup.material.canaryCiphertext,
      );
      if (ok) {
        matchedVaultId = lookup.vaultId;
        break;
      }
    }

    if (matchedVaultId == null) {
      throw const crypto.WrongPasswordException();
    }

    // 3. Full unlock with the matched vault.
    final result = await repo.unlockWithPassword(matchedVaultId, password);

    state = VaultSession(
      vaultId: matchedVaultId,
      dek: result.dek,
      kek: result.kek,
      decryptedName: result.decryptedName,
    );
  }

  /// Unlocks the vault with a recovery key.
  ///
  /// Tests the recovery key against every vault's recovery-wrapped DEK.
  /// The first vault that decrypts successfully is the one we open.
  ///
  /// Throws [WrongRecoveryKeyException] if no vault matches.
  /// Throws [VaultApiException] on HTTP errors.
  Future<void> unlockWithRecoveryKey(String recoveryKeyHex) async {
    final repo = ref.read(vaultRepositoryProvider);
    final recoveryKey = decodeRecoveryKey(recoveryKeyHex);

    // 1. Get all vaults and their unlock materials.
    final vaults = await repo.listVaults();

    if (vaults.isEmpty) {
      throw const NoVaultsException();
    }

    // 2. Test recovery key against each vault.
    for (final vault in vaults) {
      final ok = await repo.verifyRecoveryKey(vault.id, recoveryKey);
      if (ok) {
        // 3. Full unlock with recovery key.
        final dek = await repo.unlockWithRecoveryKey(vault.id, recoveryKey);

        state = VaultSession(
          vaultId: vault.id,
          dek: dek,
          kek: null, // No KEK when unlocked via recovery key.
          decryptedName: vault.name, // Use plaintext name from metadata.
        );
        return;
      }
    }

    throw const WrongRecoveryKeyException();
  }

  /// Creates a new vault, unlocks it, and returns the recovery key for
  /// one-time display.
  ///
  /// The caller MUST display the recovery key to the user and then discard
  /// it — it is NEVER stored.
  ///
  /// Throws [DuplicatePasswordException] if another vault already uses this
  /// password (canary validation succeeds against an existing vault).
  Future<String> createVault(String name, String password) async {
    final repo = ref.read(vaultRepositoryProvider);

    // 1. Check for duplicate password — test against existing canaries.
    try {
      final lookups = await repo.listUnlockMaterials();
      for (final lookup in lookups) {
        final ok = await repo.testCanary(
          password: password,
          salt: lookup.material.salt,
          canaryIv: lookup.material.canaryIv,
          canaryCiphertext: lookup.material.canaryCiphertext,
        );
        if (ok) {
          throw const DuplicatePasswordException();
        }
      }
    } on NoVaultsException {
      // No existing vaults — this is expected, continue.
    }

    // 2. Create the vault.
    final result = await repo.createVault(name, password);

    // 3. Unlock immediately after creation.
    final unlockResult = await repo.unlockWithPassword(result.vault.id, password);

    state = VaultSession(
      vaultId: result.vault.id,
      dek: unlockResult.dek,
      kek: unlockResult.kek,
      decryptedName: unlockResult.decryptedName,
    );

    // 4. Return the encoded recovery key for one-time display.
    return encodeRecoveryKey(result.recoveryKey);
  }

  /// Verifies that a user-supplied recovery key truly unlocks the vault
  /// (performs actual GCM unwrap — not string comparison).
  Future<bool> verifyRecoveryKey(String recoveryKeyHex) async {
    final repo = ref.read(vaultRepositoryProvider);
    final recoveryKey = decodeRecoveryKey(recoveryKeyHex);
    if (state == null) return false;
    return repo.verifyRecoveryKey(state!.vaultId, recoveryKey);
  }

  /// Locks the vault — clears the DEK, KEK, and decrypted name from memory.
  ///
  /// After this call, the UI returns to the unlock screen.
  /// The keys are gone — the user must re-enter their password.
  void lock() {
    state = null;
  }

  /// Test-only: injects a pre-built session without going through unlock.
  ///
  /// This bypasses password validation and Argon2id — use ONLY in tests.
  /// Setting to `null` simulates a lock event, which observers
  /// (viewer dialogs, etc.) must react to by closing themselves.
  @visibleForTesting
  void setTestSession(VaultSession? session) {
    state = session;
  }
}

// ============================================================
// Exceptions
// ============================================================

/// Thrown when [VaultSessionNotifier.unlockWithPassword] finds no vaults
/// on the server. The UI should show the "create first vault" flow.
final class NoVaultsException implements Exception {
  const NoVaultsException();

  @override
  String toString() => 'NoVaultsException: no vaults exist';
}

/// Thrown when the user tries to create a vault with a password that
/// already unlocks an existing vault.
final class DuplicatePasswordException implements Exception {
  const DuplicatePasswordException();

  @override
  String toString() =>
      'DuplicatePasswordException: password already used by another vault';
}

/// Thrown when [VaultSessionNotifier.unlockWithRecoveryKey] fails for all
/// vaults.
final class WrongRecoveryKeyException implements Exception {
  const WrongRecoveryKeyException();

  @override
  String toString() => 'WrongRecoveryKeyException: invalid recovery key';
}
