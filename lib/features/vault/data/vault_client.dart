/// HTTP client for vault REST endpoints on bmo-server.
///
/// Covers the endpoints defined in the Phase 8.0 spec:
/// - `POST   /api/v1/vaults`        create a vault
/// - `GET    /api/v1/vaults`        list all vaults
/// - `GET    /api/v1/vaults/{id}`   get vault metadata
/// - `GET    /api/v1/vaults/{id}/keys`  get unlock material
/// - `DELETE /api/v1/vaults/{id}`   delete a vault
///
/// Binary fields (keys, wrapped DEKs, canaries) are base64-encoded in JSON.
/// Serialization helpers live on [VaultCreationMaterial] and
/// [VaultUnlockMaterial].
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../crypto/vault_crypto.dart';
import 'vault_models.dart';

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown by [VaultClient] for any non-2xx response from the vault API.
final class VaultApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const VaultApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => 'VaultApiException($statusCode, $errorCode): $message';
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

final class VaultClient {
  final http.Client _client;
  final String _baseUrl;

  VaultClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Vault lifecycle
  // ============================================================

  /// Creates a new vault on the server.
  ///
  /// [material] is produced by [createVault] in the crypto layer.
  /// Only the server-safe fields are sent — [VaultCreationMaterial.recoveryKey]
  /// is NOT included.
  ///
  /// Returns the created [Vault] with server-assigned id and timestamps.
  Future<Vault> createVault({
    required String name,
    required VaultCreationMaterial material,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      ...material.toJson(),
    };

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/vaults'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Vault.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Lists all vaults for the current agent.
  Future<List<Vault>> listVaults() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/vaults'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Vault.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches metadata for a single vault.
  Future<Vault> getVault(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/vaults/$id'),
    );
    _ensureOk(response);
    return Vault.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Fetches the unlock material (keys, wrapped DEKs, canaries) for a vault.
  ///
  /// Returns [VaultUnlockMaterial] ready to pass to [unlock] or
  /// [unlockWithRecoveryKey].
  Future<VaultUnlockMaterial> getKeys(String id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/vaults/$id/keys'),
    );
    _ensureOk(response);
    return VaultUnlockMaterial.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Deletes a vault and all its encrypted data.
  Future<void> deleteVault(String id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/vaults/$id'),
    );
    _ensureOk(response);
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String errorCode = 'unknown';
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorCode = decoded['error'] as String? ?? 'unknown';
        message = decoded['message'] as String? ?? response.body;
      }
    } catch (_) {
      // Body is not JSON; use raw body as message.
    }
    throw VaultApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
