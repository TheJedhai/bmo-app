import 'package:bmo_app/core/platform/file_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripFileExtension', () {
    test('removes matching extension', () {
      expect(stripFileExtension('foto.png', 'png'), 'foto');
    });

    test('matches case-insensitively', () {
      expect(stripFileExtension('foto.PNG', 'png'), 'foto');
    });

    test('leaves name without extension unchanged', () {
      expect(stripFileExtension('foto', 'png'), 'foto');
    });

    test('preserves dots in the middle', () {
      expect(stripFileExtension('v2.final.png', 'png'), 'v2.final');
    });

    test('does not cut when extension differs', () {
      expect(stripFileExtension('foto.jpeg', 'png'), 'foto.jpeg');
    });

    test('cuts only the final extension', () {
      expect(stripFileExtension('arquivo.tar.gz', 'gz'), 'arquivo.tar');
    });

    test('empty name returns empty without crashing', () {
      expect(stripFileExtension('', 'png'), '');
    });
  });
}
