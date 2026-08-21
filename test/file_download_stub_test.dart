// Test-only seam: a branch nativa (dart:io) dos testes de file_download
// não compila no chrome — os símbolos da costura stub
// (fileDownloadGalleryAccessCheck etc.) só existem na variante não-web de
// file_download.dart. O import condicional corta a dependência: chrome
// compila cases vazio (0 testes), o VM importa os testes reais. O loader
// do flutter_tester exige main declarado na própria entrada (main via
// export não resolve) — por isso import, não export.
// Mesmo padrão de vault_item_repository_test.dart e
// file_stream_writer_web_test.dart.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'file_download_stub_test_cases.dart'
    if (dart.library.js_interop) 'file_download_stub_test_cases_web.dart';

void main() => runFileDownloadStubTests();
