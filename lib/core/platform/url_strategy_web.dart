import 'package:flutter_web_plugins/url_strategy.dart' as web_plugins;

/// Liga a estratégia de URL por path (sem `#`), que só existe onde há
/// barra de endereço.
void usePathUrlStrategy() {
  web_plugins.usePathUrlStrategy();
}
