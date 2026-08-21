// Test-only seam: os testes importam dart:html, que não compila no VM do
// flutter_tester. O import condicional corta a dependência: VM importa
// cases vazio (0 testes), chrome importa os testes reais. O loader do
// flutter_tester exige main declarado na própria entrada (main via export
// não resolve) — por isso import, não export.
// Mesmo padrão de file_stream_writer_web_test.dart.
//
// O @TestOn fica no nível da library. Sobre `void main()` o runner do
// flutter_test ignora — o VM roda o arquivo mesmo assim e o chrome nem
// compila (entrypoint procura uma main que "sumiu") — e o analisador
// marca invalid_annotation_target.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'vault_item_repository_test_cases.dart'
    if (dart.library.js_interop) 'vault_item_repository_test_cases_web.dart';

void main() => runVaultItemRepositoryTests();
