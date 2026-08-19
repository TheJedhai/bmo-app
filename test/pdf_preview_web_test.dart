// Test-only seam: the web branch of the PDF preview tests imports
// dart:html, which does not compile on the VM of flutter_tester. The
// conditional import cuts the dependency: VM imports empty cases (0
// tests), chrome imports the real tests. The flutter_tester loader
// requires main declared in the entry file itself (main via export does
// not resolve) — hence import, not export.
// Same problem that motivated video_thumbnail_register.dart.
import 'pdf_preview_web_test_cases.dart'
    if (dart.library.js_interop) 'pdf_preview_web_test_cases_web.dart';

void main() => runPdfPreviewWebTests();
