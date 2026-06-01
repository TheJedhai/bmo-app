/// API models for vault metadata — camelCase in Dart, snake_case on the wire.
///
/// Binary crypto material (keys, wrapped DEKs, canaries) lives in the crypto
/// layer ([VaultCreationMaterial], [VaultUnlockMaterial]) which already has
/// its own [toJson]/[fromJson] helpers. This file only models the vault
/// envelope metadata (id, name, timestamps).
library;

import 'dart:convert';
import 'dart:typed_data';

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
      id: _parseId(json['id']),
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

/// Parses an ID field from JSON — handles both int and String values.
String _parseId(dynamic value) => value.toString();

// ---------------------------------------------------------------------------
// Vault item
// ---------------------------------------------------------------------------

/// A vault item as returned by the bmo-server REST API.
///
/// All fields except [id], [vaultId], [sizeBytes], [encryptionScheme],
/// [chunkSize], and timestamps contain encrypted data. The content blob
/// lives on the server disk and is downloaded separately via
/// `GET /vaults/{id}/items/{item_id}`.
final class VaultItem {
  final String id;
  final String vaultId;
  final Uint8List metadataBlob;
  final Uint8List metadataIv;
  final String? encryptionScheme;
  final int? chunkSize;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultItem({
    required this.id,
    required this.vaultId,
    required this.metadataBlob,
    required this.metadataIv,
    required this.encryptionScheme,
    required this.chunkSize,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: _parseId(json['id']),
      vaultId: _parseId(json['vault_id']),
      metadataBlob: base64Decode(json['metadata_blob'] as String? ?? ''),
      metadataIv: base64Decode(json['metadata_iv'] as String? ?? ''),
      encryptionScheme: json['encryption_scheme'] as String?,
      chunkSize: json['chunk_size'] as int?,
      sizeBytes: json['size_bytes'] as int? ?? 0,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

/// A vault item with decrypted metadata (file name, MIME type, original size).
///
/// This is the in-memory view returned by [VaultRepository.listItems] after
/// decrypting each item's [metadataBlob] with the DEK. The content itself is
/// NOT decrypted — use [VaultRepository.downloadItem] for that.
///
/// ## Security: NEVER log or persist the decrypted file name or MIME type.
final class VaultItemDecrypted {
  final String id;
  final String vaultId;

  /// Original file name (decrypted from metadata).
  final String fileName;

  /// MIME type (decrypted from metadata).
  final String mimeType;

  /// Original plaintext file size in bytes (decrypted from metadata).
  final int originalSize;

  /// Encryption scheme used for the content: "gcm_single" or "gcm_chunked".
  final String? encryptionScheme;

  /// Chunk size in bytes (only for "gcm_chunked").
  final int? chunkSize;

  /// Encrypted blob size on disk (header + all chunk ciphertexts).
  final int sizeBytes;

  final DateTime createdAt;
  final DateTime updatedAt;

  const VaultItemDecrypted({
    required this.id,
    required this.vaultId,
    required this.fileName,
    required this.mimeType,
    required this.originalSize,
    required this.encryptionScheme,
    required this.chunkSize,
    required this.sizeBytes,
    required this.createdAt,
    required this.updatedAt,
  });
}
