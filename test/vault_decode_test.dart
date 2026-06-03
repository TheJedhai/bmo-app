// Unit tests for the binary decode helpers in VaultChunkedCipher.
//
// Tests that _decodeUint32BE and _decodeUint64BE produce correct results
// for values whose byte patterns triggered JS-specific bugs in the old
// bit-shift implementation:
//
//   Bug A — 64-bit shift truncation: JavaScript `<<` takes shift % 32,
//     so << 56 → << 24, << 48 → << 16, etc.  The high 4 bytes overlapped
//     with the low 4 bytes, corrupting any value whose high 32 bits were
//     non-zero (e.g. original_size ≥ 4 GiB).
//
//   Bug B — 32-bit signed result: even for shifts within 0–31, the result
//     of a JS `<<` is a *signed* 32-bit integer.  If bit 31 is set the
//     value is negative, and Dart's Uint8List(negative) throws
//     "Invalid argument: Invalid array length".
//
// All tests go through the public buildHeader/parseHeader round-trip so the
// Dart compiler cannot constant-fold the internal helpers away — we're
// exercising the actual runtime code path.
//
// Run: flutter test --platform=chrome test/vault_decode_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/vault/crypto/vault_chunked_cipher.dart';
import 'package:bmo_app/features/vault/crypto/vault_cipher.dart';

void main() {
  group('decode helpers (via buildHeader ↔ parseHeader round-trip)', () {
    // =========================================================================
    // originalSize — values that trigger JS 32-bit signed overflow (Bug B)
    // =========================================================================
    group('originalSize with bit 31 set', () {
      /// Any originalSize ≥ 2³¹ (2 147 483 648) has bit 31 set in the low
      /// 32-bit word.  With the old shift-based decoder the JS `<< 24` on
      /// byte 17 produced a negative signed-32 result → garbage.

      test('originalSize = 2_500_000_000 (≈ 2.3 GiB, bit 31 set)', () {
        const size = 2500000000;
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size),
            reason: 'bit 31 is set — old JS code returned a negative or '
                'garbled value');
      });

      test('originalSize = 3_000_000_000 (≈ 2.8 GiB, bit 31 set)', () {
        const size = 3000000000;
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size));
      });

      test('originalSize = 4_000_000_000 (≈ 3.7 GiB, bits 31+30 set)', () {
        const size = 4000000000;
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size));
      });
    });

    // =========================================================================
    // originalSize — values that trigger JS 64-bit shift truncation (Bug A)
    // =========================================================================
    group('originalSize with high 32 bits non-zero', () {
      /// Any originalSize ≥ 2³² (4 294 967 296) has non-zero high bytes.
      /// With the old shift-based decoder the JS `<< 56` → `<< 24` etc.
      /// meant the high bytes overlapped the low bytes → garbage.

      test('originalSize = 5_000_000_000 (≈ 4.7 GiB, high bytes non-zero)', () {
        const size = 5000000000; // 0x1_2A05_F200
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size),
            reason: 'high 32 bits are non-zero — old JS code overlapped '
                'high and low bytes via shift-truncation, producing garbage');
      });

      test('originalSize = 10_000_000_000 (≈ 9.3 GiB)', () {
        const size = 10000000000; // 0x2_540B_E400
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size));
      });

      test('originalSize = 1_000_000_000_000 (≈ 931 GiB)', () {
        const size = 1000000000000; // 0xE8_D4A5_1000
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        expect(parsedSize, equals(size));
      });

      test('originalSize = 0xFFFF_FFFF_FFFF (max reasonable test)', () {
        const size = 0xFFFFFFFFFFFF; // 281 474 976 710 655 ≈ 256 TiB
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: 1024 * 1024,
          originalSize: size,
        );
        final (_, _, _, parsedSize) = VaultChunkedCipher.parseHeader(header);
        // Up to 2⁵³ the multiplication is exact; 0xFFFFFFFFFFFF is ~2⁴⁸ so fine.
        expect(parsedSize, equals(size));
      });
    });

    // =========================================================================
    // chunkSize — values that trigger JS 32-bit signed overflow (Bug B)
    // =========================================================================
    group('chunkSize with bit 31 set', () {
      /// If the first byte of chunk_size (byte 9 in the header) has bit 7 set
      /// (≥ 128) the old JS `<< 24` produced a negative number.

      test('chunkSize = 2_147_483_648 (2 GiB, bit 31 exactly)', () {
        const cs = 2147483648; // 0x8000_0000
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: cs,
          originalSize: cs * 2, // so we also test combined
        );
        final (_, _, parsedCs, parsedSize) =
            VaultChunkedCipher.parseHeader(header);
        expect(parsedCs, equals(cs),
            reason: 'chunkSize >= 2³¹ — old JS code returned negative');
        expect(parsedSize, equals(cs * 2));
      });

      test('chunkSize = 3_000_000_000 (bit 31 + bit 30 set)', () {
        const cs = 3000000000; // 0xB2D0_5E00
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: Uint8List(8),
          chunkSize: cs,
          originalSize: cs * 2,
        );
        final (_, _, parsedCs, parsedSize) =
            VaultChunkedCipher.parseHeader(header);
        expect(parsedCs, equals(cs));
        expect(parsedSize, equals(cs * 2));
      });

      // Practical values — 16 MiB and 32 MiB do NOT have bit 31 set,
      // but 128 MiB does NOT either (0x0800_0000 has bit 27 set, not 31).
      // The smallest chunk size with bit 31 set is 2 GiB, which is
      // unrealistic for a chunk but tests the edge case.
    });

    // =========================================================================
    // Combined: high originalSize + large chunkSize
    // =========================================================================
    group('combined high values', () {
      test('5 GB file, 64 MiB chunks', () {
        const chunkSize = 64 * 1024 * 1024; // 67 108 864
        const originalSize = 5000000000; // 5 GB
        final header = VaultChunkedCipher.buildHeader(
          noncePrefix: VaultCipher.randomBytes(8),
          chunkSize: chunkSize,
          originalSize: originalSize,
        );
        final (_, noncePrefix, parsedCs, parsedSize) =
            VaultChunkedCipher.parseHeader(header);
        expect(parsedCs, equals(chunkSize));
        expect(parsedSize, equals(originalSize));

        // totalChunks must be correct.
        final total =
            VaultChunkedCipher.totalChunks(parsedSize, parsedCs);
        final expectedTotal =
            (originalSize + chunkSize - 1) ~/ chunkSize;
        expect(total, equals(expectedTotal));
      });
    });
  });
}
