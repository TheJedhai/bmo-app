// Unit tests for byte-based mime detection (magic number).
//
// Platform-agnostic (VM + Chrome):
// 1. one case per supported format
// 2. HEIC bytes with .jpg extension → image/heic (bytes beat extension)
// 3. unknown bytes → falls back to extension
// 4. empty / shorter-than-header bytes → application/octet-stream, no crash
//
// Run: flutter test test/core/file_mime_test.dart

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/utils/file_mime.dart';

/// ISO-BMFF minimal header: box size 16 + 'ftyp' + brand + 4 bytes de lixo.
Uint8List ftyp(String brand) => Uint8List.fromList(
      [0, 0, 0, 16, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0],
    );

void main() {
  final cases = <({String name, Uint8List bytes, String expected})>[
    (
      name: 'JPEG',
      bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
      expected: 'image/jpeg',
    ),
    (
      name: 'PNG',
      bytes: Uint8List.fromList(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      expected: 'image/png',
    ),
    (
      name: 'GIF',
      bytes: Uint8List.fromList([...'GIF89a'.codeUnits]),
      expected: 'image/gif',
    ),
    (
      name: 'WebP',
      bytes: Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
      expected: 'image/webp',
    ),
    (
      name: 'BMP',
      bytes: Uint8List.fromList([0x42, 0x4D, 0x00, 0x00, 0x00, 0x00]),
      expected: 'image/bmp',
    ),
    (
      name: 'TIFF',
      bytes: Uint8List.fromList([0x49, 0x49, 0x2A, 0x00]),
      expected: 'image/tiff',
    ),
    (
      name: 'HEIC',
      bytes: ftyp('heic'),
      expected: 'image/heic',
    ),
    (
      name: 'AVIF',
      bytes: ftyp('avif'),
      expected: 'image/avif',
    ),
    (
      name: 'MP4',
      bytes: ftyp('isom'),
      expected: 'video/mp4',
    ),
    (
      name: 'MOV',
      bytes: ftyp('qt  '),
      expected: 'video/quicktime',
    ),
    (
      name: 'PDF',
      bytes: Uint8List.fromList([...'%PDF'.codeUnits]),
      expected: 'application/pdf',
    ),
  ];

  group('detectMimeType', () {
    for (final c in cases) {
      test('${c.name}: detecta pelos bytes', () {
        expect(
          detectMimeType(bytes: c.bytes, fileName: 'arquivo.bin'),
          c.expected,
        );
      });
    }

    test('HEIC renomeado para .jpg: bytes vencem extensão', () {
      expect(
        detectMimeType(bytes: ftyp('heic'), fileName: 'foto.jpg'),
        'image/heic',
      );
    });

    test('bytes que não identificam nada: cai na extensão', () {
      expect(
        detectMimeType(
          bytes: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
          fileName: 'documento.pdf',
        ),
        'application/pdf',
      );
    });

    test('bytes vazios: application/octet-stream, sem quebrar', () {
      expect(
        detectMimeType(bytes: Uint8List(0), fileName: 'arquivo.bin'),
        'application/octet-stream',
      );
    });

    test('bytes menores que o header: application/octet-stream, sem quebrar',
        () {
      expect(
        detectMimeType(bytes: Uint8List.fromList([0xFF]), fileName: 'semext'),
        'application/octet-stream',
      );
    });

    test('marca HEIC menos comum (hevc): image/heic', () {
      expect(
        detectMimeType(bytes: ftyp('hevc'), fileName: 'arquivo.bin'),
        'image/heic',
      );
    });
  });
}
