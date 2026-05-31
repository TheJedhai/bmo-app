// Offline WASM self-hosting acceptance test.
//
// Verifies that the production build does NOT depend on jsdelivr.net
// CDN for hash-wasm. The wasm binary must be served from local assets.
//
// This test runs WITHOUT Chrome — it's a file-content check.
// Run: dart test test/vault_offline_wasm_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WASM self-hosting acceptance', () {
    test('web/hash-wasm/index.esm.js exists and is non-trivial', () {
      final file = File('web/hash-wasm/index.esm.js');
      expect(file.existsSync(), isTrue,
          reason: 'web/hash-wasm/index.esm.js must exist for offline KDF');
      final size = file.lengthSync();
      expect(size, greaterThan(100000),
          reason: 'hash-wasm ESM should be ~253 KB (contains inline WASM)');
    });

    test('web/index.html pre-loads hash-wasm locally', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html.contains('/hash-wasm/index.esm.js'), isTrue,
          reason: 'index.html must import local hash-wasm ESM');
      expect(html.contains('window.hashwasm'), isTrue,
          reason: 'index.html must set window.hashwasm for dargon2');
    });

    test('web/index.html does NOT reference jsdelivr.net', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html.contains('jsdelivr.net'), isFalse,
          reason: 'index.html must NOT contain any CDN reference');
      expect(html.contains('jsdelivr'), isFalse,
          reason: 'index.html must NOT contain any CDN reference');
    });

    test('no CDN reference in entire web/ directory', () {
      final webDir = Directory('web');
      for (final entity in webDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.html')) {
          final content = entity.readAsStringSync();
          expect(content.contains('jsdelivr'), isFalse,
              reason: '${entity.path} must not reference jsdelivr CDN');
        }
        if (entity is File && entity.path.endsWith('.js')) {
          final content = entity.readAsStringSync();
          // Ignore hash-wasm itself (it might have jsdelivr in comments)
          if (entity.path.contains('hash-wasm')) continue;
          expect(content.contains('jsdelivr'), isFalse,
              reason: '${entity.path} must not reference jsdelivr CDN');
        }
      }
    });
  });
}
