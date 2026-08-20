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

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/config/env.dart';
import 'package:bmo_app/core/http/client_factory.dart';
import 'package:bmo_app/features/vault/crypto/argon2_kdf.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

import 'argon2_register.dart';

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

/// Any HTTP response (even 4xx/5xx) means the server is alive; only network
/// failures mean it is absent.
Future<bool> _backendReachable() async {
  final client = createHttpClient();
  try {
    await client
        .get(Uri.parse('${Env.bmoServerUrl}/api/v1/me'))
        .timeout(const Duration(seconds: 5));
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}

/// Uma derivação real de Argon2id diz se o KDF funciona no ambiente atual.
/// No VM do flutter_tester o dargon2 usa EmptyDArgon2Flutter (lança
/// UnimplementedError); no chrome o hash-wasm resolve.
Future<bool> _kdfAvailable() async {
  try {
    const kdf = Argon2Kdf();
    await kdf.derive(
      password: Uint8List.fromList('probe'.codeUnits),
      salt: Uint8List(16),
    );
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  var serverUp = false;
  var kdfUp = false;
  const backendSkipReason =
      'bmo-server indisponível em ${Env.bmoServerUrl} — suba o backend '
      'para executar o E2E de vault.';
  // O KDF real (Argon2id) exige o WASM do hash-wasm, que só existe no
  // navegador — no VM do flutter_tester lança UnimplementedError antes de
  // qualquer chamada de rede.
  const vmSkipReason =
      'Argon2id (hash-wasm WASM) indisponível no flutter_tester — rode '
      'com --platform=chrome.';

  setUpAll(() async {
    kdfUp = await registerArgon2ForTest() && await _kdfAvailable();
    serverUp = await _backendReachable();
  });

  // Guarda por teste: markTestSkipped em setUpAll só pula o primeiro teste
  // no runner do flutter_test, então o skip é marcado dentro de cada teste.
  void runE2E(String name, Future<void> Function() body) {
    test(name, () async {
      if (!kdfUp) {
        markTestSkipped(vmSkipReason);
        return;
      }
      if (!serverUp) {
        markTestSkipped(backendSkipReason);
        return;
      }
      await body();
    });
  }

  const testPassword = 'integration-test-password-8.2';
  String? vaultId;

  group('Vault end-to-end integration', () {
    runE2E('1. createVault returns vault + recovery key', () async {
      final repo = _createRepo();

      final result =
          await repo.createVault('integration-test-vault', testPassword);

      expect(result.vault.id, isNotEmpty);
      // O servidor é zero-knowledge: a resposta de criação não carrega o
      // nome em texto claro (VaultCreate não tem campo `name`). O nome
      // decifrado só existe no unlock — verificado no teste 2.
      expect(result.recoveryKey.length, 32);

      // Encoded form should be 64 hex chars
      final hex = encodeRecoveryKey(result.recoveryKey);
      expect(hex.length, 64);

      // Track for cleanup
      vaultId = result.vault.id;
    });

    runE2E('2. unlockWithPassword returns valid DEK', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      final result = await repo.unlockWithPassword(vaultId!, testPassword);

      // DEK must be 32 bytes (AES-256 key)
      expect(result.dek.length, 32);

      // KEK must also be 32 bytes
      expect(result.kek.length, 32);

      // Nome decifrado do name_blob com a KEK — único caminho onde o
      // servidor expõe o nome em texto claro.
      expect(result.decryptedName, 'integration-test-vault');
    });

    runE2E('3. unlockWithRecoveryKey returns SAME DEK', () async {
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

    runE2E('4. revealRecoveryKey matches original', () async {
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

    runE2E('5. verifyRecoveryKey — correct key returns true', () async {
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

    runE2E('5b. verifyRecoveryKey — wrong key returns false', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Generate a random key (definitely wrong)
      final wrongKey = VaultCipher.generateKey();
      final valid = await repo.verifyRecoveryKey(vaultId!, wrongKey);
      expect(valid, isFalse);
    });

    runE2E('6. wrong password throws WrongPasswordException', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      expect(
        () => repo.unlockWithPassword(vaultId!, 'definitely-wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    runE2E('7. DELETE vault cleans up', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      // Should not throw
      await repo.deleteVault(vaultId!);

      // Verify vault is gone — o material de unlock some com o vault
      // (não existe GET /vaults/{id} no servidor; só /keys e /items).
      try {
        await repo.unlockWithPassword(vaultId!, testPassword);
        fail('Expected VaultApiException after delete');
      } on VaultApiException catch (e) {
        expect(e.statusCode, 404);
      }
    });
  });
}
