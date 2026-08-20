// Integration test: VaultRepository end-to-end against a DISPOSABLE
// bmo-server instance.
//
// NEVER run against production. The target URL is hardcoded to a loopback
// disposable server (port 8091) and a runtime guard fails the test if the
// target is ever pointed at production (Tailscale host or port 8089).
//
// Run with the helper script, which starts a scratch server (temp DB + temp
// blob dir) and tears it down afterwards:
//   test/vault_integration_run.sh
//
// ## Test flow (Phase 8.2 spec):
// 1. Create vault with password
// 2. Unlock with password → valid DEK + decrypted name
// 3. Wrong password → WrongPasswordException
// 4. DELETE test vault at end (cleanup)
//
// ## Security: This test NEVER logs passwords, DEKs, or any plaintext key
// material.
@Tags(['integration'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/http/client_factory.dart';
import 'package:bmo_app/features/vault/crypto/argon2_kdf.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

import 'argon2_register.dart';

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Disposable bmo-server on a dedicated port (8091) — distinct from the
/// vault_item suite (8090) and from production (8089). Started by
/// test/vault_integration_run.sh with a temporary DB and blob dir.
const _testServerUrl = 'http://127.0.0.1:8091';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Hard guard: this suite must NEVER hit production. Only an HTTP loopback
/// disposable server is acceptable — the production server (Tailscale
/// hostname, or its local port 8089) fails this check immediately.
void _assertDisposableTarget() {
  final uri = Uri.parse(_testServerUrl);
  final isLoopback =
      uri.scheme == 'http' && (uri.host == '127.0.0.1' || uri.host == 'localhost');
  if (!isLoopback || uri.port == 8089) {
    fail(
      'vault_integration_test aponta para $_testServerUrl — produção ou '
      'URL não descartável. Rode via test/vault_integration_run.sh.',
    );
  }
}

/// Creates a real [VaultRepository] pointed at the disposable bmo-server.
VaultRepository _createRepo() {
  final client = createHttpClient();
  return VaultRepository(
    VaultClient(client: client, baseUrl: _testServerUrl),
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
        .get(Uri.parse('$_testServerUrl/api/v1/me'))
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
      'bmo-server descartável indisponível em $_testServerUrl — rode '
      'test/vault_integration_run.sh para executar o E2E de vault.';
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
      _assertDisposableTarget();
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
    runE2E('1. createVault returns vault', () async {
      final repo = _createRepo();

      final vault =
          await repo.createVault('integration-test-vault', testPassword);

      expect(vault.id, isNotEmpty);
      // O servidor é zero-knowledge: a resposta de criação não carrega o
      // nome em texto claro (VaultCreate não tem campo `name`). O nome
      // decifrado só existe no unlock — verificado no teste 2.

      // Track for cleanup
      vaultId = vault.id;
    });

    runE2E('2. unlockWithPassword returns valid DEK', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      final result = await repo.unlockWithPassword(vaultId!, testPassword);

      // DEK must be 32 bytes (AES-256 key)
      expect(result.dek.length, 32);

      // Nome decifrado do name_blob com a KEK — único caminho onde o
      // servidor expõe o nome em texto claro.
      expect(result.decryptedName, 'integration-test-vault');
    });

    runE2E('3. wrong password throws WrongPasswordException', () async {
      final repo = _createRepo();
      expect(vaultId, isNotNull);

      expect(
        () => repo.unlockWithPassword(vaultId!, 'definitely-wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    runE2E('4. DELETE vault cleans up', () async {
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
