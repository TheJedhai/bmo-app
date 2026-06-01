import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/bmo_theme.dart';
import 'core/widgets/bmo_frame.dart';
import 'core/widgets/bmo_dock.dart';
import 'core/widgets/tab_page.dart';
import 'core/navigation/tab_provider.dart';
import 'core/events/events_provider.dart';
import 'features/chat/chat_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/home_devices/presentation/home_devices_screen.dart';
import 'features/missions/presentation/missions_screen.dart';
import 'features/rss/presentation/rss_screen.dart';
import 'features/vault/presentation/vault_screen.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      theme: BmoTheme.themeData,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      locale: const Locale('pt', 'BR'),
      home: const Scaffold(
        body: BmoFrame(
          child: _BmoShell(),
        ),
      ),
    );
  }
}

class _BmoShell extends ConsumerWidget {
  const _BmoShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    ref.watch(eventsListenerProvider); // Prime SSE connection at startup.

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: currentTab.index,
            children: const [
              TabPage(keepAlive: false, child: HomeScreen()),
              TabPage(keepAlive: true, child: ChatScreen()),
              TabPage(keepAlive: true, child: MissionsScreen()),
              TabPage(keepAlive: true, child: HomeDevicesScreen()),
              TabPage(keepAlive: true, child: RssScreen()),
              TabPage(keepAlive: false, child: VaultScreen()),
            ],
          ),
        ),
        const BmoDock(),
      ],
    );
  }
}
