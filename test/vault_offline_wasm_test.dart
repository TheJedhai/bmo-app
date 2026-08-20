// Offline WASM self-hosting acceptance test.
//
// Verifies that the production build does NOT depend on jsdelivr.net
// CDN for hash-wasm. The wasm binary must be served from local assets.
//
// This test runs WITHOUT Chrome — it's a file-content check.
// Run: dart test test/vault_offline_wasm_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Remove // and /* */ comments, preserving string literals. The scan's
/// job is exactly to catch jsdelivr in strings (the CDN fallback is a
/// dynamic import URL) — a naive regex strip would blind it to URLs
/// inside "https://cdn.jsdelivr.net/..." strings.
String _stripJsComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      final quote = c;
      out.write(c);
      i++;
      while (i < source.length && source[i] != quote) {
        if (source[i] == '\\' && i + 1 < source.length) {
          out.write(source[i]);
          out.write(source[i + 1]);
          i += 2;
        } else {
          out.write(source[i]);
          i++;
        }
      }
      if (i < source.length) {
        out.write(source[i]); // closing quote
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Remove <!-- --> comments, preserving the rest verbatim.
String _stripHtmlComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('<!--', i)) {
      final end = source.indexOf('-->', i + 4);
      i = end == -1 ? source.length : end + 3;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

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
        if (entity is! File) continue;
        final path = entity.path;
        final String content;
        if (path.endsWith('.js')) {
          content = _stripJsComments(entity.readAsStringSync());
        } else if (path.endsWith('.html')) {
          content = _stripHtmlComments(entity.readAsStringSync());
        } else {
          continue;
        }
        // Ignore hash-wasm itself (vendored library — not our code).
        if (path.contains('hash-wasm')) continue;
        expect(content.contains('jsdelivr'), isFalse,
            reason: '$path must not reference jsdelivr CDN');
      }
    });
  });
}
