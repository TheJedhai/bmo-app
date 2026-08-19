// Test-only seam: a branch web dos testes do writer importa dart:js_interop,
// que não compila no VM do flutter_tester. O import condicional corta a
// dependência: VM importa cases vazio (0 testes), chrome importa os testes
// reais. O loader do flutter_tester exige main declarado na própria entrada
// (main via export não resolve) — por isso import, não export.
// Mesmo problema que motivou video_thumbnail_register.dart.
import 'file_stream_writer_web_test_cases.dart'
    if (dart.library.js_interop) 'file_stream_writer_web_test_cases_web.dart';

void main() => runFileStreamWriterWebTests();
