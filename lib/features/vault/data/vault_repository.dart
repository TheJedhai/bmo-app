/// Repository orchestrating vault create / unlock / item flows.
///
/// Connects the crypto core (Phase 8.1) to the bmo-server backend (Phase 8.0)
/// via [VaultClient]. Each method combines one or more HTTP calls with
/// client-side cryptographic operations.
///
/// ## Key material lifecycle
/// - The **DEK** lives only in memory — returned by unlock methods, consumed
///   by item encryption/decryption (Phase 8.3).
///
/// ## Security rules (NEVER break these):
/// - NEVER log passwords, DEKs, or plaintext.
/// - The DEK lives ONLY in memory.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import '../crypto/vault_chunked_cipher.dart';
import '../crypto/vault_cipher.dart';
import '../crypto/vault_crypto.dart' as crypto;
import '../crypto/vault_envelope.dart';
import '../crypto/vault_kdf.dart';
import '../crypto/argon2_kdf.dart';
import 'vault_client.dart';
import 'vault_models.dart';
import 'vault_thumbnail.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Returned by [VaultRepository.unlockWithPassword].
///
/// Holds the DEK (for item encryption) and the decrypted vault name.
final class VaultUnlockResult {
  /// 32-byte Data Encryption Key — encrypts/decrypts vault items.
  final Uint8List dek;

  /// The vault name, decrypted from [VaultUnlockMaterial.nameBlob] with the
  /// KEK. **NEVER persist or log.**
  final String decryptedName;

  const VaultUnlockResult({required this.dek, required this.decryptedName});
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final class VaultRepository {
  final VaultClient _client;
  final VaultKdf _kdf;

  /// Max PUT attempts per chunk before the upload is aborted. 409 and other
  /// 4xx responses are NOT retried (they are real errors — see
  /// [_putChunkWithRetry]); only transient network failures and 5xx/429 are.
  final int _maxChunkAttempts;

  /// Base backoff between chunk PUT retries. Multiplied by the attempt number
  /// (attempt 1 → 1×, attempt 2 → 2×). Default: 500ms, 1s.
  final Duration _chunkRetryDelay;

  VaultRepository(
    this._client, {
    VaultKdf? kdf,
    int maxChunkAttempts = 3,
    Duration chunkRetryDelay = const Duration(milliseconds: 500),
  })  : _kdf = kdf ?? const Argon2Kdf(),
        _maxChunkAttempts = maxChunkAttempts,
        _chunkRetryDelay = chunkRetryDelay;

  // ============================================================
  // Create
  // ============================================================

  /// Creates a new vault with the given [name] and [password].
  ///
  /// 1. Runs [crypto.createVault] from the crypto layer (salt, KEK, DEK,
  ///    wraps, canary, name blob). The recovery wraps are generated on
  ///    purpose and sent — they stay inert server-side until the master
  ///    password feature ships.
  /// 2. POSTs the server-safe material to the backend.
  /// 3. Returns the created [Vault] metadata.
  Future<Vault> createVault(
    String name,
    String password,
  ) async {
    final material = await crypto.createVault(password, name, kdf: _kdf);
    return _client.createVault(name: name, material: material);
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
  /// Returns the DEK (for item operations) and the decrypted vault name.
  ///
  /// Throws [VaultApiException] on HTTP errors.
  /// Throws [crypto.WrongPasswordException] if the password is incorrect.
  Future<VaultUnlockResult> unlockWithPassword(
    String vaultId,
    String password,
  ) async {
    final material = await _client.getKeys(vaultId);

    // Derive KEK
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

    // Decrypt vault name
    final decryptedName = await crypto.decryptName(
      kek,
      material.nameIv,
      material.nameBlob,
    );

    return VaultUnlockResult(dek: dek, decryptedName: decryptedName);
  }

  // ============================================================
  // Vault management
  // ============================================================

  /// Fetches unlock material for ALL vaults in a single request.
  ///
  /// Returns a list of (vaultId, minimal unlock material) pairs for
  /// password testing without knowing which vault the password belongs to.
  Future<List<VaultUnlockLookup>> listUnlockMaterials() =>
      _client.getUnlockMaterials();

  /// Tests a [password] against a single vault's canary.
  ///
  /// Derives the KEK from [password] + [salt] (Argon2id), then validates
  /// the canary. Returns `true` if the password is correct for this vault.
  ///
  /// This is cheaper than a full unlock — it only downloads the canary
  /// material (via [listUnlockMaterials]) and validates locally.
  ///
  /// **NEVER log [password].**
  Future<bool> testCanary({
    required String password,
    required Uint8List salt,
    required Uint8List canaryIv,
    required Uint8List canaryCiphertext,
  }) async {
    final passwordBytes = Uint8List.fromList(password.codeUnits);
    final kek = await _kdf.derive(password: passwordBytes, salt: salt);
    return validateCanary(kek, canaryIv, canaryCiphertext);
  }

  /// Deletes a vault and all its encrypted data.
  ///
  /// **Destructive.** The caller should confirm with the user first.
  Future<void> deleteVault(String id) => _client.deleteVault(id);

  // ============================================================
  // Item upload
  // ============================================================

  /// Uploads an encrypted item to a vault.
  ///
  /// 1. Encrypts [fileName], [mimeType], and the file's original size as
  ///    metadata via AES-GCM single-shot (small, one round-trip).
  /// 2. Generates a JPEG thumbnail if the MIME type is image/* or video/*
  ///    (always an enhancement — never breaks the upload).
  /// 3. Uploads the content. Two routes, chosen by whether the ORIGINAL file
  ///    is accessible ([originalFile] != null), never by platform:
  ///    - **Streaming** (image_picker; any picker that hands us the original
  ///      file): loops `read slice → encrypt → PUT → discard`, one chunk in
  ///      memory at a time. Progress fires BEFORE the first chunk.
  ///    - **In-memory** (bytes-only, e.g. file_picker on web): the old
  ///      `_splitIntoChunks → encryptChunks → _concatBlob` route, a single
  ///      multipart POST.
  ///
  /// [dek] is the 32-byte data encryption key from unlock.
  /// [fileBytes] is the full plaintext content for the in-memory route; may be
  /// null when [originalFile] is provided (content is streamed straight from
  /// the file, so the caller never materializes it).
  /// [originalFile] is the ORIGINAL picked file when accessible: real path on
  /// iOS (both pickers), blob URL backed by the picked File on web
  /// (image_picker). Null when the picker delivered only bytes (file_picker
  /// on web).
  /// [sourcePath] keeps the path-based thumbnail route; the effective path is
  /// `originalFile?.path ?? sourcePath`.
  ///
  /// [onProgress] is called with `(bytesSent, totalBytes)` during the upload
  /// phase. In the streaming route the first call fires before any chunk is
  /// sent (the UI cannot show a frozen screen), then once per chunk.
  ///
  /// Returns [VaultItemDecrypted] with the server-assigned id and timestamps.
  ///
  /// ## Security: NEVER log [dek], [fileBytes], [fileName], or any plaintext.
  ///
  /// ## Thumbnail robustness: any failure in thumbnail generation or encryption
  /// is silently caught — the content upload always proceeds. Thumbnails are an
  /// enhancement, not a requirement.
  Future<VaultItemDecrypted> uploadItem(
    String vaultId,
    Uint8List dek,
    Uint8List? fileBytes,
    String fileName,
    String mimeType, {
    void Function(int sent, int total)? onProgress,
    XFile? originalFile,
    String? sourcePath,
  }) async {
    final originalSize =
        originalFile != null ? await originalFile.length() : fileBytes!.length;

    // 1. Encrypt metadata (single-shot GCM).
    final metadataJson = jsonEncode({
      'fileName': fileName,
      'mimeType': mimeType,
      'originalSize': originalSize,
    });
    final (metadataIv, metadataBlob) = await const VaultCipher().encrypt(
      dek,
      Uint8List.fromList(utf8.encode(metadataJson)),
    );

    // 2. Generate and encrypt thumbnail (optional — never breaks upload).
    String? thumbnailBlobBase64;
    String? thumbnailIvBase64;
    try {
      final thumbnailBytes = await _generateUploadThumbnail(
        fileBytes,
        mimeType,
        sourcePath: originalFile?.path ?? sourcePath,
      );
      if (thumbnailBytes != null) {
        const cipher = VaultCipher();
        final (thumbIv, thumbBlob) = await cipher.encrypt(dek, thumbnailBytes);
        thumbnailBlobBase64 = base64Encode(thumbBlob);
        thumbnailIvBase64 = base64Encode(thumbIv);
      }
    } catch (_) {
      // Thumbnail is an enhancement — upload proceeds without it.
      thumbnailBlobBase64 = null;
      thumbnailIvBase64 = null;
    }

    // 3. Upload content.
    final VaultItem item;
    if (originalFile != null) {
      item = await _uploadChunked(
        vaultId: vaultId,
        dek: dek,
        originalFile: originalFile,
        originalSize: originalSize,
        metadataBlob: metadataBlob,
        metadataIv: metadataIv,
        thumbnailBlobBase64: thumbnailBlobBase64,
        thumbnailIvBase64: thumbnailIvBase64,
        onProgress: onProgress,
      );
    } else {
      final blob = await _buildFullBlob(dek, fileBytes!);
      item = await _client.uploadItem(
        vaultId: vaultId,
        encryptedBlob: blob,
        metadataBlobBase64: base64Encode(metadataBlob),
        metadataIvBase64: base64Encode(metadataIv),
        encryptionScheme: 'gcm_chunked',
        chunkSize: VaultChunkedCipher.defaultChunkSize,
        thumbnailBlobBase64: thumbnailBlobBase64,
        thumbnailIvBase64: thumbnailIvBase64,
        onProgress: onProgress,
      );
    }

    return VaultItemDecrypted(
      id: item.id,
      vaultId: item.vaultId,
      fileName: fileName,
      mimeType: mimeType,
      originalSize: originalSize,
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

        // Decrypt thumbnail if present (enhancement — failure is non-fatal).
        Uint8List? thumbnail;
        if (item.thumbnailBlob != null && item.thumbnailIv != null) {
          try {
            thumbnail = await cipher.decrypt(
              dek,
              item.thumbnailIv!,
              item.thumbnailBlob!,
            );
          } on VaultCipherException {
            thumbnail = null;
          }
        }

        decrypted.add(VaultItemDecrypted(
          id: item.id,
          vaultId: item.vaultId,
          fileName: metaJson['fileName'] as String? ?? 'unknown',
          mimeType: metaJson['mimeType'] as String? ?? 'application/octet-stream',
          originalSize: metaJson['originalSize'] as int? ?? 0,
          thumbnail: thumbnail,
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
  /// chunks. This is a tiny Range request (21 bytes) — ideal for caching
  /// before video playback.
  ///
  /// Callers should cache the returned header and pass it to
  /// [fetchChunkRange] for on-demand chunk decryption.
  ///
  /// NOTE: The total blob size (available via Content-Range on the 206
  /// response) is not exposed cross-origin by default — the browser Fetch
  /// API hides non-safelisted response headers unless the server sets
  /// Access-Control-Expose-Headers. If blob size is needed, call
  /// [downloadItemBlob] which uses Content-Length (safelisted).
  Future<Uint8List> fetchItemHeader(
    String vaultId,
    String itemId,
  ) async {
    // Range: bytes=0-20 (inclusive) → first 21 bytes.
    final (headerBytes, _, _) = await _client.fetchItemBlobRange(
      vaultId: vaultId,
      itemId: itemId,
      start: 0,
      end: headerByteLength - 1,
    );
    return headerBytes;
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
  /// Returns `(plaintext, httpStatus, encryptedBytesReceived)`:
  /// - [plaintext]: the decrypted chunk bytes.
  /// - [httpStatus]: the HTTP status from the server (SHOULD be 206).
  /// - [encryptedBytesReceived]: the number of encrypted bytes transferred
  ///   over the network (ciphertext + GCM tag). Callers SHOULD assert that
  ///   this equals `chunkSize + 16` (or less for the last partial chunk),
  ///   NOT the full blob size. This assertion proves the transfer was truly
  ///   partial — a bug that downloads the full blob and slices locally
  ///   would show the full blob size here, catching the regression.
  ///
  /// This is the low-level method for on-demand chunk access. For video
  /// playback (Phase 8.3d), the player requests a plaintext byte range,
  /// the range is mapped to chunk indices via [mapPlaintextRangeToChunks],
  /// and each chunk is fetched and decrypted via this method.
  ///
  /// Throws [VaultCipherException] if the chunk index is out of range
  /// or decryption fails (GCM tag validation).
  Future<(Uint8List, int, int)> fetchChunkRange(
    String vaultId,
    Uint8List dek,
    String itemId,
    int chunkIndex,
    Uint8List header,
  ) async {
    const chunked = VaultChunkedCipher();
    final (start, end) = chunked.chunkByteRange(header, chunkIndex);

    final (encryptedChunk, _, statusCode) = await _client.fetchItemBlobRange(
      vaultId: vaultId,
      itemId: itemId,
      start: start,
      end: end,
    );

    final plaintext = await chunked.decryptChunk(
      dek, header, chunkIndex, encryptedChunk);
    return (plaintext, statusCode, encryptedChunk.length);
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

  /// Builds the full encrypted blob (header + all chunks) in memory. Used on
  /// the in-memory route only — routed here when there is no original file to
  /// stream (bytes-only, e.g. web file_picker).
  Future<Uint8List> _buildFullBlob(Uint8List dek, Uint8List fileBytes) async {
    final plaintextChunks = _splitIntoChunks(
      fileBytes,
      VaultChunkedCipher.defaultChunkSize,
    );
    const chunked = VaultChunkedCipher();
    final (header, encryptedChunks) = await chunked.encryptChunks(
      dek,
      plaintextChunks,
    );
    return _concatBlob(header, encryptedChunks);
  }

  /// Streams the original [originalFile] to the server chunk-by-chunk, never
  /// holding more than one chunk in memory: read slice → encrypt → PUT →
  /// discard.
  ///
  /// The wire format is identical to the in-memory route (same 21-byte
  /// header, same per-chunk nonce/AAD) — the server just assembles the chunks
  /// into the same blob, and the existing download path reads it unchanged.
  /// On any failure [VaultClient.abortChunkedUpload] is called so no partial
  /// item is left behind.
  Future<VaultItem> _uploadChunked({
    required String vaultId,
    required Uint8List dek,
    required XFile originalFile,
    required int originalSize,
    required Uint8List metadataBlob,
    required Uint8List metadataIv,
    required String? thumbnailBlobBase64,
    required String? thumbnailIvBase64,
    required void Function(int sent, int total)? onProgress,
  }) async {
    const chunked = VaultChunkedCipher();
    final chunkSize = VaultChunkedCipher.defaultChunkSize;
    final total = VaultChunkedCipher.totalChunks(originalSize, chunkSize);
    final header = VaultChunkedCipher.newHeader(
      chunkSize: chunkSize,
      originalSize: originalSize,
    );

    final session = await _client.beginChunkedUpload(
      vaultId: vaultId,
      header: header,
    );

    var contentSent = 0;
    try {
      // Progress BEFORE the first chunk — the user must not see a frozen
      // screen while the first chunk is read + encrypted + uploaded.
      onProgress?.call(0, originalSize);

      for (var i = 0; i < total; i++) {
        final isLast = i == total - 1;
        final start = i * chunkSize;
        final end = isLast ? originalSize : start + chunkSize;
        final plaintext = await _readRange(originalFile, start, end);
        final encrypted = await chunked.encryptChunk(
          dek,
          header,
          i,
          isLast,
          plaintext,
        );
        await _putChunkWithRetry(vaultId, session.uploadId, i, encrypted);
        contentSent += plaintext.length;
        // plaintext & encrypted drop out of scope here — one chunk at a time.
        onProgress?.call(contentSent, originalSize);
      }

      return await _client.completeChunkedUpload(
        vaultId: vaultId,
        uploadId: session.uploadId,
        metadataBlobBase64: base64Encode(metadataBlob),
        metadataIvBase64: base64Encode(metadataIv),
        chunkSize: chunkSize,
        thumbnailBlobBase64: thumbnailBlobBase64,
        thumbnailIvBase64: thumbnailIvBase64,
      );
    } catch (e) {
      // Every failure path aborts so no partial item is left on the server.
      try {
        await _client.abortChunkedUpload(
          vaultId: vaultId,
          uploadId: session.uploadId,
        );
      } catch (_) {
        // Abort is best-effort — the original error propagates.
      }
      rethrow;
    }
  }

  /// Reads bytes `[start]..[end)` of [file] into one buffer via
  /// `XFile.openRead(start, end)` — native reads a dart:io file slice, web
  /// reads a Blob.slice — neither materializes the whole file.
  static Future<Uint8List> _readRange(XFile file, int start, int end) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(start, end)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// PUTs one chunk, retrying transient failures (network / HTTP 5xx / 429)
  /// on the SAME index — the PUT is idempotent per index. 409
  /// `chunk_out_of_order` and all other 4xx are real errors: never retried,
  /// the whole upload is aborted.
  Future<void> _putChunkWithRetry(
    String vaultId,
    String uploadId,
    int index,
    Uint8List encryptedChunk,
  ) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await _client.putChunk(
          vaultId: vaultId,
          uploadId: uploadId,
          index: index,
          encryptedChunk: encryptedChunk,
        );
        return;
      } on VaultApiException catch (e) {
        if (e.statusCode < 500) rethrow; // 409 + other 4xx: real error
        if (attempt >= _maxChunkAttempts) rethrow;
        await Future<void>.delayed(_chunkRetryDelay * attempt);
      } catch (_) {
        // Transient network failure (SocketException, ClientException, etc.).
        if (attempt >= _maxChunkAttempts) rethrow;
        await Future<void>.delayed(_chunkRetryDelay * attempt);
      }
    }
  }

  /// Generates the upload thumbnail. Uses the bytes-based route when
  /// [fileBytes] is present (covers images and bytes-only video), else the
  /// path-based route for video when the original file is accessible.
  static Future<Uint8List?> _generateUploadThumbnail(
    Uint8List? fileBytes,
    String mimeType, {
    String? sourcePath,
  }) async {
    if (fileBytes != null) {
      return generateThumbnail(fileBytes, mimeType, sourcePath: sourcePath);
    }
    if (mimeType.startsWith('video/') && sourcePath != null) {
      return getThumbnailVideoFromPath(sourcePath);
    }
    return null;
  }
}
