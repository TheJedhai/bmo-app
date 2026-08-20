// Test-only seam: os testes importam dart:js_interop, que não compila no
// VM do flutter_tester. O import condicional corta a dependência: VM importa
// cases vazio (0 testes), chrome importa os testes reais. O loader do
// flutter_tester exige main declarado na própria entrada (main via export
// não resolve) — por isso import, não export.
// Mesmo padrão de file_stream_writer_web_test.dart.
import 'package:flutter_test/flutter_test.dart' show TestOn;

import 'vault_cdn_defense_test_cases.dart'
    if (dart.library.js_interop) 'vault_cdn_defense_test_cases_web.dart';

@TestOn('browser')
void main() => runVaultCdnDefenseTests();
