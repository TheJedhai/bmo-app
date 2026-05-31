// Unit tests for VaultRepository — mock the HTTP layer, exercise all flows.
//
// These tests use real crypto (Argon2id + WebCrypto) but mock the HTTP
// client so no bmo-server is needed.
//
// Run: flutter test --platform=chrome test/vault_repository_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_crypto.dart';
import 'package:bmo_app/features/vault/crypto/vault_envelope.dart';
import 'package:bmo_app/features/vault/crypto/vault_kdf.dart';
import 'package:bmo_app/features/vault/data/vault_client.dart';
import 'package:bmo_app/features/vault/data/vault_models.dart';
import 'package:bmo_app/features/vault/data/vault_repository.dart';

// ---------------------------------------------------------------------------
// Mock KDF — fast, deterministic, no WASM needed
// ---------------------------------------------------------------------------

/// A fast mock KDF that derives a key from password + salt.
/// NOT SECURE — only for tests that mock HTTP and don't need real Argon2id.
final class MockKdf implements VaultKdf {
  const MockKdf();

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
  }) async {
    // Deterministic but irreversible: XOR password and salt repeatedly
    // to produce a 32-byte output. Fine for testing envelope logic.
    final result = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      result[i] = password[i % password.length] ^ salt[i % salt.length] ^ (i * 0x1B);
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [VaultRepository] with a [MockClient] and [MockKdf].
VaultRepository _createRepo(MockClient mockClient) {
  final client = VaultClient(
    client: mockClient,
    baseUrl: 'http://localhost:8089',
  );
  return VaultRepository(client, kdf: const MockKdf());
}

/// Creates a [Vault] JSON response body.
Map<String, dynamic> _vaultJson(String id, String name) => {
      'id': id,
      'name': name,
      'created_at': '2025-06-15T10:30:00Z',
      'updated_at': '2025-06-15T10:30:00Z',
    };

/// Extracts the unlock-material fields from a [VaultCreationMaterial] into
/// a JSON map matching the `GET /vaults/{id}/keys` response shape.
Map<String, dynamic> _keysJsonFromMaterial(VaultCreationMaterial m) {
  // VaultCreationMaterial.toJson() already excludes recoveryKey.
  return m.toJson();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -----------------------------------------------------------------------
  // createVault
  // -----------------------------------------------------------------------
  group('createVault', () {
    test('creates vault and returns recovery key', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/vaults') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // Verify name is in the payload
          expect(body['name'], 'Test Vault');
          // Verify key material fields are present and base64-encoded
          expect(body['salt'], isA<String>());
          expect(body['wrapped_dek'], isA<String>());
          expect(body['dek_iv'], isA<String>());
          expect(body['canary_ciphertext'], isA<String>());
          expect(body['canary_iv'], isA<String>());
          expect(body['recovery_wrapped_dek'], isA<String>());
          expect(body['recovery_dek_iv'], isA<String>());
          expect(body['recovery_key_wrapped'], isA<String>());
          expect(body['recovery_key_wrap_iv'], isA<String>());
          // Recovery key must NOT be in the payload
          expect(body.containsKey('recovery_key'), isFalse);

          return http.Response(
            jsonEncode(_vaultJson('vault-1', 'Test Vault')),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final result = await repo.createVault('Test Vault', 'test-password');

      // Verify vault metadata
      expect(result.vault.id, 'vault-1');
      expect(result.vault.name, 'Test Vault');

      // Verify recovery key is 32 bytes
      expect(result.recoveryKey.length, 32);

      // Verify recovery key can be encoded
      final hex = encodeRecoveryKey(result.recoveryKey);
      expect(hex.length, 64);
    });
  });

  // -----------------------------------------------------------------------
  // unlockWithPassword
  // -----------------------------------------------------------------------
  group('unlockWithPassword', () {
    test('unlocks with correct password', () async {
      const password = 'correct-password';

      // Create real crypto material
      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final result = await repo.unlockWithPassword('vault-1', password);

      // Verify DEK is 32 bytes
      expect(result.dek.length, 32);

      // Verify KEK is 32 bytes
      expect(result.kek.length, 32);
    });

    test('throws WrongPasswordException for wrong password', () async {
      const password = 'correct-password';

      // Create real crypto material
      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      expect(
        () => repo.unlockWithPassword('vault-1', 'wrong-password'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('throws VaultApiException on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'not_found', 'message': 'Vault not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = _createRepo(mockClient);

      expect(
        () => repo.unlockWithPassword('nonexistent', 'password'),
        throwsA(isA<VaultApiException>()),
      );
    });
  });

  // -----------------------------------------------------------------------
  // unlockWithRecoveryKey
  // -----------------------------------------------------------------------
  group('unlockWithRecoveryKey', () {
    test('unlocks with correct recovery key', () async {
      const password = 'some-password';

      // Create real crypto material
      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final dek =
          await repo.unlockWithRecoveryKey('vault-1', material.recoveryKey);

      // Verify DEK is 32 bytes
      expect(dek.length, 32);
    });

    test('throws VaultCipherException for wrong recovery key', () async {
      const password = 'some-password';

      // Create real crypto material
      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // Generate a different random key (definitely wrong)
      final wrongKey = VaultCipher.generateKey();

      expect(
        () => repo.unlockWithRecoveryKey('vault-1', wrongKey),
        throwsA(isA<VaultCipherException>()),
      );
    });
  });

  // -----------------------------------------------------------------------
  // revealRecoveryKey
  // -----------------------------------------------------------------------
  group('revealRecoveryKey', () {
    test('reveals recovery key from KEK-unlocked vault', () async {
      const password = 'test-password';

      // Create real crypto material
      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // First unlock to get KEK
      final unlockResult =
          await repo.unlockWithPassword('vault-1', password);

      // Then reveal recovery key using KEK
      final revealedKey =
          await repo.revealRecoveryKey('vault-1', unlockResult.kek);

      // Should match the original recovery key
      expect(revealedKey, material.recoveryKey);

      // Encoded form should match too
      expect(
        encodeRecoveryKey(revealedKey),
        encodeRecoveryKey(material.recoveryKey),
      );
    });
  });

  // -----------------------------------------------------------------------
  // verifyRecoveryKey
  // -----------------------------------------------------------------------
  group('verifyRecoveryKey', () {
    test('returns true for correct recovery key', () async {
      const password = 'test-password';

      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final valid = await repo.verifyRecoveryKey(
        'vault-1',
        material.recoveryKey,
      );
      expect(valid, isTrue);
    });

    test('returns false for wrong recovery key', () async {
      const password = 'test-password';

      final material = await createVault(password, kdf: const MockKdf());
      final keysJson = _keysJsonFromMaterial(material);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/vault-1/keys') {
          return http.Response(
            jsonEncode(keysJson),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final wrongKey = VaultCipher.generateKey();
      final valid = await repo.verifyRecoveryKey('vault-1', wrongKey);
      expect(valid, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // listVaults / getVault / deleteVault
  // -----------------------------------------------------------------------
  group('vault management', () {
    test('listVaults returns vault list', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults') {
          return http.Response(
            jsonEncode([
              _vaultJson('v-1', 'Personal'),
              _vaultJson('v-2', 'Work'),
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final vaults = await repo.listVaults();
      expect(vaults.length, 2);
      expect(vaults[0].id, 'v-1');
      expect(vaults[0].name, 'Personal');
      expect(vaults[1].id, 'v-2');
      expect(vaults[1].name, 'Work');
    });

    test('getVault returns single vault', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/v1/vaults/v-1') {
          return http.Response(
            jsonEncode(_vaultJson('v-1', 'Personal')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      final vault = await repo.getVault('v-1');
      expect(vault.id, 'v-1');
      expect(vault.name, 'Personal');
    });

    test('deleteVault succeeds on 200', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'DELETE' &&
            request.url.path == '/api/v1/vaults/v-1') {
          return http.Response('', 200);
        }
        return http.Response('not found', 404);
      });

      final repo = _createRepo(mockClient);

      // Should not throw
      await repo.deleteVault('v-1');
    });

    test('deleteVault throws VaultApiException on 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'not_found', 'message': 'Vault not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = _createRepo(mockClient);

      expect(
        () => repo.deleteVault('nonexistent'),
        throwsA(isA<VaultApiException>()),
      );
    });
  });
}
