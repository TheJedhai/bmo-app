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
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../crypto/vault_crypto.dart';
import 'vault_models.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A vault ID + its unlock material, returned by
/// [VaultClient.getUnlockMaterials].
///
/// Use this to test a password or recovery key against every vault without
/// knowing in advance which vault the key belongs to.
final class VaultUnlockLookup {
  final String vaultId;
  final VaultUnlockMaterial material;

  const VaultUnlockLookup({required this.vaultId, required this.material});
}

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

  /// Fetches unlock material for ALL vaults in a single request.
  ///
  /// Calls `GET /api/v1/vaults/unlock-material` which returns a list of
  /// vault IDs with their salt, canary, and recovery-wrapped DEK — just
  /// enough to test a password (or recovery key) against every vault without
  /// revealing which vaults exist.
  ///
  /// Returns a list where each entry has a [vaultId] and the minimal
  /// [VaultUnlockMaterial] needed for password/recovery-key validation.
  /// After finding the matching vault, call [getKeys] for the full material.
  Future<List<VaultUnlockLookup>> getUnlockMaterials() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/vaults/unlock-material'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return VaultUnlockLookup(
        vaultId: map['id']?.toString() ?? '',
        material: VaultUnlockMaterial.fromJson(map),
      );
    }).toList();
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
  // Vault items
  // ============================================================

  /// Uploads an encrypted item to a vault via multipart form.
  ///
  /// [encryptedBlob] is the full encrypted blob (header + chunk ciphertexts
  /// concatenated). [metadataBlobBase64] and [metadataIvBase64] are the
  /// base64-encoded encrypted metadata (file name, MIME type, size).
  ///
  /// [encryptionScheme] must be "gcm_single" or "gcm_chunked".
  /// [chunkSize] is required for "gcm_chunked", null for "gcm_single".
  ///
  /// [onProgress] is called with (bytesSent, totalBytes) during upload.
  /// For Flutter web, this fires as the stream is consumed.
  Future<VaultItem> uploadItem({
    required String vaultId,
    required List<int> encryptedBlob,
    required String metadataBlobBase64,
    required String metadataIvBase64,
    required String encryptionScheme,
    required int? chunkSize,
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/vaults/$vaultId/items');
    final request = http.MultipartRequest('POST', uri);

    // Attach blob as a file — stream with progress tracking.
    final total = encryptedBlob.length;
    final trackedStream = _progressStream(encryptedBlob, total, onProgress);
    request.files.add(http.MultipartFile(
      'blob',
      trackedStream,
      total,
      filename: 'encrypted.blob',
    ));

    // Metadata fields.
    request.fields['metadata_blob'] = metadataBlobBase64;
    request.fields['metadata_iv'] = metadataIvBase64;
    request.fields['encryption_scheme'] = encryptionScheme;
    if (chunkSize != null) {
      request.fields['chunk_size'] = chunkSize.toString();
    }

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _ensureOk(response);
    return VaultItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Lists all items in a vault.
  ///
  /// Returns metadata for each item. Content blobs are NOT included —
  /// use [downloadItemBlob] or [fetchItemBlobRange] to retrieve content.
  Future<List<VaultItem>> listItems(String vaultId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/vaults/$vaultId/items'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => VaultItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Downloads the full encrypted blob for an item.
  ///
  /// Returns the raw bytes (header + all chunk ciphertexts).
  ///
  /// [onProgress] is called with (bytesReceived, totalBytes) as the
  /// streamed response is read.
  ///
  /// **Web memory safety**: When [contentLength] is known we pre-allocate a
  /// single [Uint8List] and write chunks directly into it.  This avoids
  /// building a growable `List<int>` backed by a JS Array, where each byte
  /// becomes a boxed JS number (~8× overhead) and array growth can fail with
  /// "Invalid array length" for downloads > ~200 MiB.
  ///
  /// Throws [VaultApiException] if the item is not found (404) or the
  /// blob file is missing from disk (410).
  Future<Uint8List> downloadItemBlob({
    required String vaultId,
    required String itemId,
    void Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse('$_baseUrl/api/v1/vaults/$vaultId/items/$itemId'),
    );
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode == 410) {
      throw VaultApiException(
        statusCode: 410,
        errorCode: 'blob_file_missing',
        message: 'Blob file not found for item $itemId',
      );
    }
    _ensureOkStreamed(streamedResponse);

    final total = streamedResponse.contentLength ?? 0;

    if (total > 0) {
      // Fast path: pre-allocate a single Uint8List and write chunks directly.
      // This avoids the JS Array intermediate on web and eliminates the risk
      // of "Invalid array length" from growable-list backing-store growth.
      final bytes = Uint8List(total);
      var offset = 0;
      await for (final chunk in streamedResponse.stream) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
        onProgress?.call(offset, total);
      }
      return bytes;
    }

    // Fallback: content-length unknown (chunked transfer encoding).
    // Use a BytesBuilder which is more memory-efficient than List<int>.
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in streamedResponse.stream) {
      builder.add(chunk);
      received += chunk.length;
      onProgress?.call(received, received);
    }
    return builder.toBytes();
  }

  /// Fetches a byte range of an item's encrypted blob.
  ///
  /// [start] and [end] are inclusive byte offsets into the blob.
  /// Sets `Range: bytes=start-end` on the request.
  ///
  /// Returns `(bytes, totalBlobSize, statusCode)`:
  /// - [bytes]: the partial content from the server.
  /// - [totalBlobSize]: parsed from Content-Range (e.g. `bytes 0-20/5242901`).
  /// - [statusCode]: the HTTP status (206 on success, or 200 if the server
  ///   ignored the Range header — callers should assert 206 to prove partial
  ///   transfer rather than assuming it).
  ///
  /// Throws [VaultApiException] on 404 (item not found), 410 (blob file
  /// missing), or 416 (range not satisfiable).
  Future<(Uint8List, int, int)> fetchItemBlobRange({
    required String vaultId,
    required String itemId,
    required int start,
    required int end,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse('$_baseUrl/api/v1/vaults/$vaultId/items/$itemId'),
    );
    request.headers['Range'] = 'bytes=$start-$end';

    final streamedResponse = await _client.send(request);
    final statusCode = streamedResponse.statusCode;

    if (statusCode == 410) {
      throw VaultApiException(
        statusCode: 410,
        errorCode: 'blob_file_missing',
        message: 'Blob file not found for item $itemId',
      );
    }
    if (statusCode == 416) {
      throw VaultApiException(
        statusCode: 416,
        errorCode: 'range_not_satisfiable',
        message: 'Range $start-$end not satisfiable for item $itemId',
      );
    }
    _ensureOkStreamed(streamedResponse);

    // Parse total size from Content-Range: "bytes <start>-<end>/<total>"
    // Header name is case-insensitive per HTTP spec; Fetch API may lowercase it.
    final contentRange = _headerValue(streamedResponse.headers, 'content-range');
    final totalSize = _parseContentRangeTotal(contentRange);

    final bytes = <int>[];
    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
    }
    return (Uint8List.fromList(bytes), totalSize, statusCode);
  }

  /// Deletes a single item from a vault.
  ///
  /// Returns normally on 204. Throws [VaultApiException] on 404.
  Future<void> deleteItem(String vaultId, String itemId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/vaults/$vaultId/items/$itemId'),
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

  /// Validates a streamed response status code, decoding the body for error
  /// details when possible.
  void _ensureOkStreamed(http.StreamedResponse response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    // For streamed responses we can't read the body twice, so use the
    // reason phrase as the message.
    throw VaultApiException(
      statusCode: response.statusCode,
      errorCode: 'request_failed',
      message: response.reasonPhrase ?? 'HTTP ${response.statusCode}',
    );
  }

  /// Case-insensitive header lookup.
  static String _headerValue(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final key in headers.keys) {
      if (key.toLowerCase() == lower) return headers[key] ?? '';
    }
    // Try direct lookup as fallback (works for mock/http package maps).
    return headers[name] ?? '';
  }

  /// Parses the total size from a Content-Range header value.
  /// Format: `bytes start-end/total` — returns the total.
  /// Returns 0 if the header is missing or malformed.
  static int _parseContentRangeTotal(String contentRange) {
    final slash = contentRange.lastIndexOf('/');
    if (slash < 0) return 0;
    return int.tryParse(contentRange.substring(slash + 1).trim()) ?? 0;
  }

  /// Wraps [data] in a stream that calls [onProgress] as bytes are consumed.
  static Stream<List<int>> _progressStream(
    List<int> data,
    int total,
    void Function(int sent, int total)? onProgress,
  ) async* {
    if (onProgress == null) {
      yield data;
      return;
    }
    // Emit in chunks to provide progress over time.
    const chunkSize = 256 * 1024; // 256 KiB
    var sent = 0;
    while (sent < total) {
      final end = sent + chunkSize > total ? total : sent + chunkSize;
      yield data.sublist(sent, end);
      sent = end;
      onProgress(sent, total);
    }
  }
}
