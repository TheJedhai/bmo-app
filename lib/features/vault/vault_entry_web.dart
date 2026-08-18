/// Reexporta a API pública do vault para builds web (dart.library.js_interop).
///
/// Exportar apenas o que os call sites de hoje usam. Se um novo call site
/// precisar de mais símbolos do vault, adicione o reexport aqui.
library;

export 'presentation/vault_screen.dart';
