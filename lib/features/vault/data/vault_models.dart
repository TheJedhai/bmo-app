/// API models for vault metadata — camelCase in Dart, snake_case on the wire.
///
/// Binary crypto material (keys, wrapped DEKs, canaries) lives in the crypto
/// layer ([VaultCreationMaterial], [VaultUnlockMaterial]) which already has
/// its own [toJson]/[fromJson] helpers. This file only models the vault
/// envelope metadata (id, name, timestamps).
library;

import '../crypto/vault_crypto.dart';

// ---------------------------------------------------------------------------
// Vault
// ---------------------------------------------------------------------------

/// A vault as returned by the bmo-server REST API.
///
/// Holds metadata only — key material is fetched separately via
/// `GET /vaults/{id}/keys` and deserialized into [VaultUnlockMaterial].
final class Vault {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vault({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vault.fromJson(Map<String, dynamic> json) {
    return Vault(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parses a datetime from JSON — handles both ISO 8601 strings and Unix
/// timestamps (seconds as int, multiplied by 1000 for ms).
DateTime _parseDateTime(dynamic value) {
  if (value is String) return DateTime.parse(value);
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  return DateTime.now().toUtc();
}
