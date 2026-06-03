/// Chunked AES-256-GCM encryption for large files (photos, videos).
///
/// Instead of encrypting the entire file as a single GCM blob — which prevents
/// random access because GCM authenticates the tag only at the end — the file
/// is split into fixed-size chunks. Each chunk is independently encrypted with
/// AES-256-GCM, carrying its own nonce and authenticated metadata (AAD).
///
/// ## Why chunked GCM and not streaming GCM?
/// GCM produces the authentication tag only at the end of the ciphertext.
/// A single GCM stream requires processing all bytes from start to verify
/// any middle portion — impossible for seeking in a video or serving an HTTP
/// Range request. Per-chunk GCM makes every chunk self-contained, verifiable,
/// and independently decryptable.
///
/// ## Nonce construction (critical for security)
/// GCM security collapses if a (key, nonce) pair is ever reused. Each file
/// generates a fresh random 8-byte nonce prefix. Per-chunk nonces are:
///
/// ```text
/// nonce = nonce_prefix (8 bytes) || encodeUint32BE(chunk_index) (4 bytes)
/// ```
///
/// This gives 12 bytes total (96-bit GCM nonce). The random prefix guarantees
/// uniqueness across files (even with the same DEK), and the counter guarantees
/// uniqueness within a file. Both must fit in the 12-byte GCM nonce:
/// 8 bytes random leaves 4 bytes for the counter → up to 2^32 (~4 billion)
/// chunks per file.
///
/// ## Authenticated metadata (AAD)
/// Each chunk's GCM operation binds the full header + chunk metadata as
/// associated data:
///
/// ```text
/// AAD = header (21 bytes) || encodeUint32BE(chunk_index) (4 bytes)
///       || is_last (1 byte, 0 or 1)
/// ```
///
/// This provides:
/// - **Header authentication**: any modification to format_version, nonce_prefix,
///   chunk_size, or original_size in the header changes the AAD for every chunk
///   → GCM tag validation fails for all chunks.
/// - **Anti-reordering**: swapping chunks or claiming a different index
///   causes AAD mismatch → GCM tag validation fails.
/// - **Anti-truncation**: the last chunk carries `is_last=1`. [decryptAll]
///   requires at least one chunk to authenticate with `is_last=1` before
///   returning success. Removing the last chunk (or all chunks) causes
///   the check to fail.
///
/// ## Blob format (v2)
///
/// ```text
/// Offset  Size  Field
/// 0       1     format_version (u8, = 2)
/// 1       8     nonce_prefix (8 random bytes)
/// 9       4     chunk_size (u32, big-endian) — bytes per full chunk
/// 13      8     original_size (u64, big-endian) — total plaintext bytes
/// ─────── ──    header = 21 bytes ──
/// 21      var   chunk 0: ciphertext ‖ GCM tag (16 bytes)
/// ...     var   chunk 1..N-1
/// ```
///
/// Each chunk's ciphertext is `plaintext_size + 16` bytes (GCM tag appended).
/// The last chunk may be smaller than [chunk_size].
///
/// ## Security rules (NEVER break these):
/// - NEVER log, print, or debugPrint DEKs, plaintext, nonces, nonce prefixes,
///   or any key material.
/// - NEVER reuse a nonce prefix. A fresh 8-byte random prefix is generated
///   per file via crypto.getRandomValues.
library;

import 'dart:typed_data';

import 'vault_cipher.dart';

// ---------------------------------------------------------------------------
// Header format constants
// ---------------------------------------------------------------------------

/// Blob format version. Increment when the header layout changes in a
/// backward-incompatible way.
const int _formatVersion = 2;

/// Total header size in bytes.
///
/// version(1) + nonce_prefix(8) + chunk_size(4) + original_size(8) = 21.
const int headerByteLength = 21;

/// Byte offset of the nonce prefix within the header.
const int _offsetNoncePrefix = 1;

/// Byte offset of the chunk size (u32 BE) within the header.
const int _offsetChunkSize = 9;

/// Byte offset of the original size (u64 BE) within the header.
const int _offsetOriginalSize = 13;

/// Random nonce prefix length in bytes. The remaining 4 bytes of the 12-byte
/// GCM nonce carry the chunk index as u32 big-endian.
const int _noncePrefixLength = 8;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Chunked AES-256-GCM encryption/decryption for large files.
///
/// Each chunk is independently encrypted with its own nonce and AAD, enabling
/// random access, streaming, and HTTP Range requests without processing the
/// entire file.
///
/// Uses [VaultCipher] for the underlying AES-GCM per chunk — no duplicated
/// crypto primitives.
final class VaultChunkedCipher {
  /// Default chunk size: 1 MiB (1 048 576 bytes).
  ///
  /// Chosen because:
  /// - Small enough that a single chunk decrypts quickly for random access
  /// - Large enough to keep the GCM overhead low (16 bytes per chunk, or
  ///   ~0.0015% overhead at 1 MiB)
  /// - Aligns with typical file-system block sizes and HTTP buffer sizes
  static const int defaultChunkSize = 1024 * 1024;

  const VaultChunkedCipher();

  // -- Header ----------------------------------------------------------------

  /// Builds a v2 blob header from the encryption parameters.
  ///
  /// [noncePrefix] must be exactly 8 random bytes (generated once per file).
  /// [chunkSize] is the full-chunk plaintext size in bytes.
  /// [originalSize] is the total plaintext file size in bytes.
  static Uint8List buildHeader({
    required Uint8List noncePrefix,
    required int chunkSize,
    required int originalSize,
  }) {
    final header = Uint8List(headerByteLength);
    header[0] = _formatVersion;
    header.setRange(_offsetNoncePrefix, _offsetNoncePrefix + _noncePrefixLength,
        noncePrefix);
    _encodeUint32BE(header, _offsetChunkSize, chunkSize);
    _encodeUint64BE(header, _offsetOriginalSize, originalSize);
    return header;
  }

  /// Parses a blob header.
  ///
  /// Returns `(version, noncePrefix, chunkSize, originalSize)`.
  ///
  /// Throws [VaultCipherException] if the header is too short or the format
  /// version is unsupported.
  static (int, Uint8List, int, int) parseHeader(Uint8List header) {
    if (header.length < headerByteLength) {
      throw VaultCipherException(
        'Header too short: expected $headerByteLength bytes, got ${header.length}',
      );
    }
    final version = header[0];
    if (version != _formatVersion) {
      throw VaultCipherException(
        'Unsupported blob format version: $version (expected $_formatVersion)',
      );
    }
    final noncePrefix = Uint8List.sublistView(
      header,
      _offsetNoncePrefix,
      _offsetNoncePrefix + _noncePrefixLength,
    );
    final chunkSize = _decodeUint32BE(header, _offsetChunkSize);
    final originalSize = _decodeUint64BE(header, _offsetOriginalSize);
    return (version, noncePrefix, chunkSize, originalSize);
  }

  /// Number of chunks needed to cover [originalSize] bytes with the given
  /// [chunkSize] (ceiling division).
  ///
  /// Returns 1 for [originalSize] = 0 — the empty file always has one sentinel
  /// chunk carrying the `is_last` flag, so decryption can authenticate the
  /// empty state instead of accepting it without proof.
  static int totalChunks(int originalSize, int chunkSize) {
    if (originalSize == 0) return 1; // sentinel chunk for empty files
    return (originalSize + chunkSize - 1) ~/ chunkSize;
  }

  // -- Encryption ------------------------------------------------------------

  /// Encrypts [plaintextChunks] with AES-256-GCM, one chunk at a time.
  ///
  /// [dek] is the 32-byte data encryption key.
  /// [plaintextChunks] is a list of plaintext byte arrays. All chunks except
  /// possibly the last must be exactly [chunkSize] bytes. The last chunk may
  /// be smaller (including a single partial byte).
  ///
  /// Returns `(header, encryptedChunks)` where the header serializes all
  /// parameters needed for decryption and each encrypted chunk is
  /// `plaintext + 16-byte GCM tag`.
  ///
  /// Each encrypted chunk is independently decryptable via [decryptChunk].
  Future<(Uint8List, List<Uint8List>)> encryptChunks(
    Uint8List dek,
    List<Uint8List> plaintextChunks, {
    int chunkSize = defaultChunkSize,
  }) async {
    const cipher = VaultCipher();
    final noncePrefix = VaultCipher.randomBytes(_noncePrefixLength);

    // Ensure at least one sentinel chunk for an empty file so decryption
    // always authenticates the is_last flag (never accepts "0 chunks").
    final effectiveChunks = plaintextChunks.isEmpty
        ? <Uint8List>[Uint8List(0)]
        : plaintextChunks;

    var originalSize = 0;
    for (final chunk in effectiveChunks) {
      originalSize += chunk.length;
    }

    final header = buildHeader(
      noncePrefix: noncePrefix,
      chunkSize: chunkSize,
      originalSize: originalSize,
    );

    final total = effectiveChunks.length;
    final encryptedChunks = <Uint8List>[];

    for (var i = 0; i < total; i++) {
      final isLast = i == total - 1;
      final nonce = _buildChunkNonce(noncePrefix, i);
      final aad = _buildChunkAad(header, i, isLast);
      // Copy to a new buffer: the caller may pass sublist views whose
      // .buffer is larger than the chunk, and WebCrypto via JS interop
      // reads the whole backing buffer.
      final chunkCopy = Uint8List.fromList(effectiveChunks[i]);
      final (_, ciphertext) = await cipher.encrypt(
        dek,
        chunkCopy,
        iv: nonce,
        additionalData: aad,
      );
      encryptedChunks.add(ciphertext);
    }

    return (header, encryptedChunks);
  }

  // -- Decryption ------------------------------------------------------------

  /// Decrypts a single chunk given its index and encrypted bytes.
  ///
  /// This is the key operation for streaming/random access — the caller
  /// fetches only the bytes for [chunkIndex] from storage (using
  /// [chunkByteRange] to compute the byte range), then calls this method.
  ///
  /// [header] is the 21-byte blob header. [chunkIndex] is zero-based.
  /// [encryptedChunkBytes] is the raw `ciphertext ‖ GCM tag` for this chunk.
  ///
  /// Throws [VaultCipherException] if the chunk index is out of range, the
  /// GCM tag doesn't validate (wrong key, tampered data), or the AAD doesn't
  /// match (reordered chunk, wrong index).
  Future<Uint8List> decryptChunk(
    Uint8List dek,
    Uint8List header,
    int chunkIndex,
    Uint8List encryptedChunkBytes,
  ) async {
    final (_, noncePrefix, chunkSize, originalSize) = parseHeader(header);
    final total = totalChunks(originalSize, chunkSize);

    if (chunkIndex < 0 || chunkIndex >= total) {
      throw VaultCipherException(
        'Chunk index $chunkIndex out of range [0, ${total - 1}]',
      );
    }

    final isLast = chunkIndex == total - 1;
    final nonce = _buildChunkNonce(noncePrefix, chunkIndex);
    final aad = _buildChunkAad(header, chunkIndex, isLast);

    const cipher = VaultCipher();
    return cipher.decrypt(dek, nonce, encryptedChunkBytes,
        additionalData: aad);
  }

  /// Decrypts all chunks and returns the full original plaintext.
  ///
  /// [allEncryptedBytes] is the complete encrypted blob: the 21-byte header
  /// followed by all encrypted chunks concatenated.
  ///
  /// Validates anti-truncation via two independent checks:
  /// 1. Every chunk is read at the byte position expected from the header —
  ///    if the blob is too short, throws [VaultCipherException] immediately.
  /// 2. After all chunks are processed, at least one chunk MUST have
  ///    authenticated with `is_last=1` in its AAD. This guards against
  ///    header tampering (e.g. setting original_size=0 to bypass all GCM
  ///    checks) and against an empty `total` that never runs the loop.
  ///
  /// Never silently returns partial or empty plaintext without cryptographic
  /// proof that the last chunk was seen and validated.
  Future<Uint8List> decryptAll(
    Uint8List dek,
    Uint8List header,
    Uint8List allEncryptedBytes,
  ) async {
    final (_, noncePrefix, chunkSize, originalSize) = parseHeader(header);
    final total = totalChunks(originalSize, chunkSize);
    final plaintext = Uint8List(originalSize);
    var plaintextOffset = 0;
    var blobOffset = headerByteLength;
    var sawLast = false;

    for (var i = 0; i < total; i++) {
      final isLast = i == total - 1;
      final expectedPlaintextSize =
          isLast ? originalSize - (chunkSize * (total - 1)) : chunkSize;
      final encryptedSize = expectedPlaintextSize + 16; // +16 for GCM tag

      if (blobOffset + encryptedSize > allEncryptedBytes.length) {
        if (isLast) {
          throw const VaultCipherException(
            'Truncated blob: missing last chunk — '
            'is_last flag not authenticated (anti-truncation)',
          );
        }
        throw const VaultCipherException(
          'Truncated blob: incomplete chunk data',
        );
      }

      // Copy to a new buffer: sublist views share the parent buffer,
      // and WebCrypto via JS interop reads the whole backing buffer.
      final chunkCiphertext = Uint8List.fromList(Uint8List.sublistView(
        allEncryptedBytes,
        blobOffset,
        blobOffset + encryptedSize,
      ));

      final decrypted = await decryptChunk(dek, header, i, chunkCiphertext);
      plaintext.setRange(
        plaintextOffset,
        plaintextOffset + decrypted.length,
        decrypted,
      );
      plaintextOffset += decrypted.length;
      blobOffset += encryptedSize;
      if (isLast) {
        sawLast = true;
      }
    }

    if (!sawLast) {
      throw const VaultCipherException(
        'Truncated blob: is_last flag never authenticated — '
        'file may have been truncated or header tampered',
      );
    }

    return plaintext;
  }

  // -- Byte-range calculation ------------------------------------------------

  /// Returns the byte range `(start, end)` of [chunkIndex] within the
  /// encrypted blob (header + all chunk ciphertexts concatenated).
  ///
  /// [end] is **inclusive**, suitable for HTTP Range requests:
  /// `Range: bytes=<start>-<end>`.
  ///
  /// This is used by the caller to request only the bytes for a specific
  /// chunk from the server (Phase 8.3c).
  (int, int) chunkByteRange(Uint8List header, int chunkIndex) {
    final (_, _, chunkSize, originalSize) = parseHeader(header);
    final total = totalChunks(originalSize, chunkSize);

    if (chunkIndex < 0 || chunkIndex >= total) {
      throw VaultCipherException(
        'Chunk index $chunkIndex out of range [0, ${total - 1}]',
      );
    }

    // All full chunks before this one contribute chunkSize + 16 bytes each.
    final start = headerByteLength + chunkIndex * (chunkSize + 16);

    final isLast = chunkIndex == total - 1;
    final plaintextSize =
        isLast ? originalSize - (chunkSize * (total - 1)) : chunkSize;
    final encryptedSize = plaintextSize + 16;
    final end = start + encryptedSize - 1; // inclusive

    return (start, end);
  }
}

// ---------------------------------------------------------------------------
// Nonce and AAD construction
// ---------------------------------------------------------------------------

/// Builds a 12-byte GCM nonce for [chunkIndex] from the file's random
/// [noncePrefix].
///
/// ```text
/// nonce = nonce_prefix (8 bytes) || encodeUint32BE(chunk_index) (4 bytes)
/// ```
Uint8List _buildChunkNonce(Uint8List noncePrefix, int chunkIndex) {
  final nonce = Uint8List(VaultCipher.ivLength);
  nonce.setRange(0, _noncePrefixLength, noncePrefix);
  _encodeUint32BE(nonce, _noncePrefixLength, chunkIndex);
  return nonce;
}

/// Builds the AAD for a chunk: full header + index + is-last flag.
///
/// ```text
/// AAD = header (21 bytes) || encodeUint32BE(chunk_index) (4 bytes)
///       || is_last (1 byte, 0 or 1)
/// ```
///
/// Binding the full header authenticates all its fields (format_version,
/// nonce_prefix, chunk_size, original_size) — any header tampering causes
/// GCM tag validation to fail for every chunk.
Uint8List _buildChunkAad(Uint8List header, int chunkIndex, bool isLast) {
  final aad = Uint8List(headerByteLength + 5);
  aad.setRange(0, headerByteLength, header);
  _encodeUint32BE(aad, headerByteLength, chunkIndex);
  aad[headerByteLength + 4] = isLast ? 1 : 0;
  return aad;
}

// ---------------------------------------------------------------------------
// Binary encoding helpers (big-endian)
//
// **JS safety**: All functions use integer division (`~/`) and multiplication
// instead of bit-shift operators (`<<`, `>>`).  Dart's `<<` and `>>` compile to
// JavaScript's `<<` and `>>`, which:
// - Truncate the shift count modulo 32 (`>> 56` → `>> 24`)
// - Operate on **signed** 32-bit integers (result can be negative)
// - Convert both operands to 32-bit before shifting (high 32 bits lost)
//
// Integer division/multiplication uses full JS numbers (53-bit integer
// precision), which is safe for file sizes up to ~9 PiB.
// ---------------------------------------------------------------------------

void _encodeUint32BE(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value ~/ 16777216) & 0xFF; // value ~/ 2^24
  bytes[offset + 1] = (value ~/ 65536) & 0xFF; // value ~/ 2^16
  bytes[offset + 2] = (value ~/ 256) & 0xFF; // value ~/ 2^8
  bytes[offset + 3] = value & 0xFF;
}

/// Decodes a big-endian unsigned 32-bit integer from [bytes] at [offset].
///
/// Uses multiplication instead of bit-shift OR-ing so the result is always a
/// non-negative Dart integer, correct on both VM and JS backends.
int _decodeUint32BE(Uint8List bytes, int offset) {
  return (bytes[offset] * 16777216) + // 2^24
      (bytes[offset + 1] * 65536) + // 2^16
      (bytes[offset + 2] * 256) + // 2^8
      bytes[offset + 3];
}

void _encodeUint64BE(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value ~/ 72057594037927936) & 0xFF; // value ~/ 2^56
  bytes[offset + 1] = (value ~/ 281474976710656) & 0xFF; // value ~/ 2^48
  bytes[offset + 2] = (value ~/ 1099511627776) & 0xFF; // value ~/ 2^40
  bytes[offset + 3] = (value ~/ 4294967296) & 0xFF; // value ~/ 2^32
  bytes[offset + 4] = (value ~/ 16777216) & 0xFF; // value ~/ 2^24
  bytes[offset + 5] = (value ~/ 65536) & 0xFF; // value ~/ 2^16
  bytes[offset + 6] = (value ~/ 256) & 0xFF; // value ~/ 2^8
  bytes[offset + 7] = value & 0xFF;
}

/// Decodes a big-endian unsigned 64-bit integer from [bytes] at [offset].
///
/// Splits into high/low 32-bit halves decoded via [_decodeUint32BE] and
/// combines with multiplication.  Correct up to 2^53 - 1 (~9 PiB) on all
/// backends — far beyond any practical file size.
int _decodeUint64BE(Uint8List bytes, int offset) {
  final high = _decodeUint32BE(bytes, offset);
  final low = _decodeUint32BE(bytes, offset + 4);
  return high * 4294967296 + low; // 2^32
}
