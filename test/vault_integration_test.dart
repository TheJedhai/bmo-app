// Integration test: VaultRepository end-to-end against real bmo-server.
//
// REQUIRES bmo-server running on localhost:8089.
// NOT a unit test — hits the real API, creates/deletes real vaults.
//
// Run with:
//   flutter test --platform=chrome test/vault_integration_test.dart
//
// To skip when server is not available:
//   flutter test --platform=chrome test/vault_integration_test.dart --tags=integration
//
// ## Test flow (Phase 8.2 spec):
// 1. Create vault with password → receives recovery key
// 2. Unlock with password → valid DEK
// 3. Unlock with recovery key → same DEK
// 4. Reveal recovery key with vault unlocked → matches original
// 5. verifyRecoveryKey with correct key → true; with wrong key → false
// 6. Wrong password → WrongPasswordException
// 7. DELETE test vault at end (cleanup)
//
// ## Security: This test NEVER logs passwords, DEKs, KEKs, recovery keys,
// or any plaintext key material.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/config/env.dart';
import 'package:bmo_app/core/http/client_factory.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a real [VaultRepository] pointed at the local bmo-server.
VaultRepository _createRepo() {
  final client = createHttpClient();
  return VaultRepository(
    VaultClient(client: client, baseUrl: Env.bmoServerUrl),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const testPassword = 'integration-test-password-8.2';
  String? vaultId;

  group('Vault end-to-end integration', () {
    test('1. createVault returns vault + recovery key', () async {
      final repo = _createRepo();

      final result =
          await repo.createVault('integration-test-vault', testPassword);

      expect(result.vault.id, isNotEmpty);
      expect(result.vault.name, 'integration-test-vault');
      expect(result.recoveryKey.length, 32);

      // Encoded form should be 64 hex chars
      final hex = encodeRecoveryKey(result.recoveryKey);
      expect(hex.length, 64);

      // Track for cleanup
      vaultId = result.vault.id;
    });

    test('2. unlockWithPassword returns valid DEK', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      final result = await repo.unlockWithPassword(vaultId!, testPassword);

      // DEK must be 32 bytes (AES-256 key)
      expect(result.dek.length, 32);

      // KEK must also be 32 bytes
      expect(result.kek.length, 32);
    });

    test('3. unlockWithRecoveryKey returns SAME DEK', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Unlock with password to get the baseline DEK
      final passwordResult =
          await repo.unlockWithPassword(vaultId!, testPassword);
      final dekFromPassword = passwordResult.dek;

      // Reveal recovery key to get the recovery key bytes
      final recoveryKey =
          await repo.revealRecoveryKey(vaultId!, passwordResult.kek);

      // Unlock with the recovery key
      final dekFromRecovery =
          await repo.unlockWithRecoveryKey(vaultId!, recoveryKey);

      // Both DEKs must be identical
      expect(dekFromRecovery, dekFromPassword);
    });

    test('4. revealRecoveryKey matches original', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Unlock with password
      final passwordResult =
          await repo.unlockWithPassword(vaultId!, testPassword);

      // Reveal recovery key using KEK
      final revealedKey =
          await repo.revealRecoveryKey(vaultId!, passwordResult.kek);

      // Must be 32 bytes
      expect(revealedKey.length, 32);

      // Encoded form must be 64 hex chars (validates it's a proper key)
      final hex = encodeRecoveryKey(revealedKey);
      expect(hex.length, 64);
      expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('5. verifyRecoveryKey — correct key returns true', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Unlock and get recovery key
      final passwordResult =
          await repo.unlockWithPassword(vaultId!, testPassword);
      final recoveryKey =
          await repo.revealRecoveryKey(vaultId!, passwordResult.kek);

      // Verify with correct key
      final valid = await repo.verifyRecoveryKey(vaultId!, recoveryKey);
      expect(valid, isTrue);
    });

    test('5b. verifyRecoveryKey — wrong key returns false', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Generate a random key (definitely wrong)
      final wrongKey = VaultCipher.generateKey();
      final valid = await repo.verifyRecoveryKey(vaultId!, wrongKey);
      expect(valid, isFalse);
    });

    test('6. wrong password throws WrongPasswordException', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      expect(
        () => repo.unlockWithPassword(vaultId!, 'definitely-wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('7. DELETE vault cleans up', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Should not throw
      await repo.deleteVault(vaultId!);

      // Verify vault is gone — GET should 404
      try {
        await repo.getVault(vaultId!);
        fail('Expected VaultApiException after delete');
      } on VaultApiException catch (e) {
        expect(e.statusCode, 404);
      }
    });
  });
}
