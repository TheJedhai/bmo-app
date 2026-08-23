import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home_devices/providers/devices_providers.dart';
import '../events/events_provider.dart';
import '../platform/widget_refresh.dart';

/// Força reconexão do SSE de negócio e do WebSocket de devices quando o app
/// volta do background.
///
/// No iOS o sistema suspende o app e derruba conexões TCP silenciosamente —
/// os loops de backoff dos dois streams só reconectam em erro explícito ou
/// close limpo, então ficariam pendurados pra sempre. Na web o ciclo de vida
/// não derruba as conexões e `onPause`/`onResume` nem disparam; o gate
/// `kIsWeb` mantém o comportamento web idêntico ao de hoje.
class AppLifecycleReconnect extends ConsumerStatefulWidget {
  const AppLifecycleReconnect({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleReconnect> createState() =>
      _AppLifecycleReconnectState();
}

class _AppLifecycleReconnectState extends ConsumerState<AppLifecycleReconnect> {
  late final AppLifecycleListener _listener;
  var _backgrounded = false;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onPause: () {
        _backgrounded = true;
        // App indo pro background: recarrega o widget AGORA com o estado
        // mais recente (sem debounce — um timer de 2s poderia ser cortado
        // pela suspensão). O iOS suspende o app logo após o onPause.
        requestWidgetReload();
      },
      onResume: () {
        // iOS manda inactive → resumed também no cold start; sem flag
        // isso derrubaria a conexão recém-aberta a cada launch.
        if (kIsWeb || !_backgrounded) return;
        _backgrounded = false;
        // Invalidate descarta o elemento antigo (subscription cancelada,
        // socket fechado) antes de rebuildar e reabrir — nunca duplica.
        // A reconexão re-executa os mesmos geradores, então a identidade é
        // resolvida fresca no connect (watch de currentUserIdProvider +
        // X-User-Id lido a cada send), nunca de valor capturado.
        ref.invalidate(eventsStreamProvider);
        ref.invalidate(devicesWsStreamProvider);
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
