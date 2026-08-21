import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'core/platform/file_download.dart';
import 'core/theme/bmo_theme.dart';
import 'core/widgets/app_lifecycle_reconnect.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: BmoTheme.themeData,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      locale: const Locale('pt', 'BR'),
      // Montado na raiz (acima do Navigator), uma vez por vida do app:
      // listener de lifecycle único para SSE + WebSocket.
      builder: (context, child) =>
          AppLifecycleReconnect(child: child ?? const SizedBox.shrink()),
      routerConfig: appRouter,
    );
  }
}
