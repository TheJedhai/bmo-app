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

import 'dart:convert';
import 'dart:typed_data';

import '../crypto/vault_chunked_cipher.dart';
import '../crypto/vault_cipher.dart';
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

  // ============================================================
  // Item upload
  // ============================================================

  /// Uploads an encrypted item to a vault.
  ///
  /// 1. Encrypts [fileName], [mimeType], and [fileBytes].length as metadata
  ///    via AES-GCM single-shot (small, one round-trip).
  /// 2. Splits [fileBytes] into 1 MiB chunks and encrypts each with
  ///    [VaultChunkedCipher].
  /// 3. Posts the encrypted blob + metadata to the server.
  ///
  /// [dek] is the 32-byte data encryption key from unlock.
  /// [fileBytes] is the full plaintext file content.
  ///
  /// [onProgress] is called with `(bytesSent, totalBytes)` during the
  /// upload phase (encryption happens first, then upload progress).
  ///
  /// Returns [VaultItemDecrypted] with the server-assigned id and timestamps.
  ///
  /// ## Security: NEVER log [dek], [fileBytes], [fileName], or any plaintext.
  Future<VaultItemDecrypted> uploadItem(
    String vaultId,
    Uint8List dek,
    Uint8List fileBytes,
    String fileName,
    String mimeType, {
    void Function(int sent, int total)? onProgress,
  }) async {
    // 1. Encrypt metadata (single-shot GCM).
    final metadataJson = jsonEncode({
      'fileName': fileName,
      'mimeType': mimeType,
      'originalSize': fileBytes.length,
    });
    final (metadataIv, metadataBlob) = await const VaultCipher().encrypt(
      dek,
      Uint8List.fromList(utf8.encode(metadataJson)),
    );

    // 2. Encrypt content (chunked GCM).
    final plaintextChunks = _splitIntoChunks(
      fileBytes,
      VaultChunkedCipher.defaultChunkSize,
    );
    const chunked = VaultChunkedCipher();
    final (header, encryptedChunks) = await chunked.encryptChunks(
      dek,
      plaintextChunks,
    );

    // 3. Build full blob: header + all encrypted chunks.
    final blob = _concatBlob(header, encryptedChunks);

    // 4. Upload to server.
    final item = await _client.uploadItem(
      vaultId: vaultId,
      encryptedBlob: blob,
      metadataBlobBase64: base64Encode(metadataBlob),
      metadataIvBase64: base64Encode(metadataIv),
      encryptionScheme: 'gcm_chunked',
      chunkSize: VaultChunkedCipher.defaultChunkSize,
      onProgress: onProgress,
    );

    return VaultItemDecrypted(
      id: item.id,
      vaultId: item.vaultId,
      fileName: fileName,
      mimeType: mimeType,
      originalSize: fileBytes.length,
      encryptionScheme: item.encryptionScheme,
      chunkSize: item.chunkSize,
      sizeBytes: item.sizeBytes,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  // ============================================================
  // Item listing
  // ============================================================

  /// Lists all items in a vault, decrypting each item's metadata.
  ///
  /// Downloads ONLY the metadata for each item (id, size, encrypted name/MIME)
  /// and decrypts it with the [dek]. Content blobs are NOT downloaded.
  ///
  /// Returns items with file name, MIME type, and original size in cleartext
  /// (in memory only — NEVER persisted or logged).
  ///
  /// Items whose metadata fails to decrypt are silently skipped rather than
  /// crashing the whole list — this allows the vault to still function if
  /// individual items have corrupted metadata.
  Future<List<VaultItemDecrypted>> listItems(
    String vaultId,
    Uint8List dek,
  ) async {
    final items = await _client.listItems(vaultId);
    const cipher = VaultCipher();
    final decrypted = <VaultItemDecrypted>[];

    for (final item in items) {
      try {
        final metaJson = await _decryptMetadata(
          cipher,
          dek,
          item.metadataBlob,
          item.metadataIv,
        );
        if (metaJson == null) continue;
        decrypted.add(VaultItemDecrypted(
          id: item.id,
          vaultId: item.vaultId,
          fileName: metaJson['fileName'] as String? ?? 'unknown',
          mimeType: metaJson['mimeType'] as String? ?? 'application/octet-stream',
          originalSize: metaJson['originalSize'] as int? ?? 0,
          encryptionScheme: item.encryptionScheme,
          chunkSize: item.chunkSize,
          sizeBytes: item.sizeBytes,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ));
      } on VaultCipherException {
        // Corrupted metadata — skip this item silently.
        continue;
      }
    }

    return decrypted;
  }

  // ============================================================
  // Item download (full file)
  // ============================================================

  /// Downloads and decrypts an entire item.
  ///
  /// 1. Fetches the full encrypted blob from the server.
  /// 2. Parses the header to extract chunk parameters.
  /// 3. Decrypts all chunks via [VaultChunkedCipher.decryptAll].
  ///
  /// Returns the full plaintext file bytes. This is suitable for saving
  /// the file to disk — NOT for streaming or playback.
  ///
  /// [onProgress] is called with `(bytesReceived, totalBytes)` during the
  /// download phase.
  ///
  /// Throws [VaultApiException] on HTTP errors (404, 410).
  /// Throws [VaultCipherException] if decryption fails.
  Future<Uint8List> downloadItem(
    String vaultId,
    Uint8List dek,
    String itemId, {
    void Function(int received, int total)? onProgress,
  }) async {
    // 1. Download full blob.
    final blob = await _client.downloadItemBlob(
      vaultId: vaultId,
      itemId: itemId,
      onProgress: onProgress,
    );

    // 2. Parse header (first 21 bytes).
    final header = Uint8List.sublistView(blob, 0, headerByteLength);

    // 3. Decrypt all.
    const chunked = VaultChunkedCipher();
    return chunked.decryptAll(dek, header, blob);
  }

  // ============================================================
  // Item header fetch (for chunked random access)
  // ============================================================

  /// Fetches only the blob header (first 21 bytes) for an item.
  ///
  /// The header contains the encryption parameters (nonce prefix, chunk size,
  /// original size) needed to compute chunk byte ranges and decrypt individual
  /// chunks. This is a tiny request — ideal for caching before video playback.
  ///
  /// Callers should cache the returned header and pass it to
  /// [fetchChunkRange] for on-demand chunk decryption.
  ///
  /// Returns `(header, blobSize)` where [header] is the 21-byte blob header
  /// and [blobSize] is the total encrypted blob size from the server.
  Future<(Uint8List, int)> fetchItemHeader(
    String vaultId,
    String itemId,
  ) async {
    // Range: bytes=0-20 (inclusive) → first 21 bytes.
    final headerBytes = await _client.fetchItemBlobRange(
      vaultId: vaultId,
      itemId: itemId,
      start: 0,
      end: headerByteLength - 1,
    );
    final blobSize = await _client.getItemBlobSize(
      vaultId: vaultId,
      itemId: itemId,
    );
    return (headerBytes, blobSize);
  }

  // ============================================================
  // Chunk fetch & decrypt (random access)
  // ============================================================

  /// Fetches and decrypts a single chunk from the server.
  ///
  /// Uses [VaultChunkedCipher.chunkByteRange] to compute the exact byte
  /// range for [chunkIndex], issues an HTTP Range request for only those
  /// bytes, then decrypts the chunk with [VaultChunkedCipher.decryptChunk].
  ///
  /// [header] is the 21-byte blob header (obtained via [fetchItemHeader]
  /// or from a prior full download). Cache this — do NOT re-fetch it
  /// for every chunk.
  ///
  /// This is the low-level method for on-demand chunk access. For video
  /// playback (Phase 8.3d), the player requests a plaintext byte range,
  /// the range is mapped to chunk indices via [mapPlaintextRangeToChunks],
  /// and each chunk is fetched and decrypted via this method.
  ///
  /// Throws [VaultCipherException] if the chunk index is out of range
  /// or decryption fails (GCM tag validation).
  Future<Uint8List> fetchChunkRange(
    String vaultId,
    Uint8List dek,
    String itemId,
    int chunkIndex,
    Uint8List header,
  ) async {
    const chunked = VaultChunkedCipher();
    final (start, end) = chunked.chunkByteRange(header, chunkIndex);

    final encryptedChunk = await _client.fetchItemBlobRange(
      vaultId: vaultId,
      itemId: itemId,
      start: start,
      end: end,
    );

    return chunked.decryptChunk(dek, header, chunkIndex, encryptedChunk);
  }

  /// Deletes a single item from a vault.
  Future<void> deleteItem(String vaultId, String itemId) =>
      _client.deleteItem(vaultId, itemId);

  // ============================================================
  // Plaintext range → chunk index mapping
  // ============================================================

  /// Maps a plaintext byte range to the set of chunk indices needed to
  /// cover it, along with the byte offset and length within each chunk.
  ///
  /// This is the bridge between a video player's byte-range request and
  /// the chunked encryption layer. The caller:
  ///
  /// 1. Calls this method to get the needed `(chunkIndex, chunkByteOffset,
  ///    chunkByteLength)` tuples.
  /// 2. Fetches and decrypts each chunk via [fetchChunkRange] (or in parallel).
  /// 3. Assembles the response by slicing each decrypted chunk at the
  ///    returned offsets and concatenating.
  ///
  /// [plainStart] and [plainEnd] are inclusive offsets into the original
  /// plaintext. [chunkSize] is the chunk size from the blob header.
  /// [originalSize] is the total plaintext size from the blob header.
  ///
  /// Returns an empty list if the range is out of bounds.
  ///
  /// Example: for a 1 MiB chunk size, requesting bytes 1 500 000–2 100 000
  /// (crossing chunk boundaries 1→2) returns:
  /// ```dart
  /// [
  ///   (1, 475712, 548576),  // chunk 1: offset ~476 KiB, length ~536 KiB
  ///   (2, 0, 47600),        // chunk 2: offset 0, length ~46 KiB
  /// ]
  /// ```
  static List<(int, int, int)> mapPlaintextRangeToChunks(
    int plainStart,
    int plainEnd,
    int chunkSize,
    int originalSize,
  ) {
    if (plainStart < 0 ||
        plainEnd < 0 ||
        plainStart > plainEnd ||
        plainStart >= originalSize) {
      return const [];
    }

    final clampedEnd = plainEnd >= originalSize ? originalSize - 1 : plainEnd;
    final firstChunk = plainStart ~/ chunkSize;
    final lastChunk = clampedEnd ~/ chunkSize;
    final totalChunks = VaultChunkedCipher.totalChunks(originalSize, chunkSize);

    final result = <(int, int, int)>[];
    for (var ci = firstChunk; ci <= lastChunk && ci < totalChunks; ci++) {
      final chunkPlainStart = ci * chunkSize;
      final chunkPlainEnd = (ci == totalChunks - 1)
          ? originalSize - 1
          : chunkPlainStart + chunkSize - 1;

      final overlapStart =
          plainStart > chunkPlainStart ? plainStart : chunkPlainStart;
      final overlapEnd =
          clampedEnd < chunkPlainEnd ? clampedEnd : chunkPlainEnd;

      final offset = overlapStart - chunkPlainStart;
      final length = overlapEnd - overlapStart + 1;

      if (length > 0) {
        result.add((ci, offset, length));
      }
    }

    return result;
  }

  // ============================================================
  // Internal helpers
  // ============================================================

  /// Decrypts a metadata blob, returning the parsed JSON map.
  ///
  /// Returns `null` if decryption fails (corrupted metadata) rather than
  /// throwing — this allows [listItems] to skip corrupt items gracefully.
  static Future<Map<String, dynamic>?> _decryptMetadata(
    VaultCipher cipher,
    Uint8List dek,
    Uint8List metadataBlob,
    Uint8List metadataIv,
  ) async {
    try {
      final plaintext = await cipher.decrypt(dek, metadataIv, metadataBlob);
      final jsonStr = utf8.decode(plaintext);
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } on VaultCipherException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Splits [data] into chunks of [chunkSize] (last chunk may be smaller).
  static List<Uint8List> _splitIntoChunks(Uint8List data, int chunkSize) {
    final chunks = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      final end = offset + chunkSize;
      final chunkEnd = end > data.length ? data.length : end;
      chunks.add(Uint8List.sublistView(data, offset, chunkEnd));
      offset = chunkEnd;
    }
    return chunks;
  }

  /// Concatenates [header] + [encryptedChunks] into a single blob.
  static Uint8List _concatBlob(
    Uint8List header,
    List<Uint8List> encryptedChunks,
  ) {
    final totalLen =
        header.length + encryptedChunks.fold<int>(0, (s, c) => s + c.length);
    final blob = Uint8List(totalLen);
    var offset = 0;
    blob.setRange(offset, offset + header.length, header);
    offset += header.length;
    for (final chunk in encryptedChunks) {
      blob.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return blob;
  }
}
