import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/bmo_theme.dart';
import 'core/widgets/bmo_frame.dart';
import 'core/widgets/bmo_dock.dart';
import 'core/widgets/tab_page.dart';
import 'core/navigation/tab_provider.dart';
import 'features/chat/chat_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/missions/presentation/missions_screen.dart';

class BmoApp extends ConsumerWidget {
  const BmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'BMO',
      debugShowCheckedModeBanner: false,
      theme: BmoTheme.themeData,
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

    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: currentTab.index,
            children: const [
              TabPage(keepAlive: false, child: HomeScreen()),
              TabPage(keepAlive: true, child: ChatScreen()),
              TabPage(keepAlive: true, child: MissionsScreen()),
            ],
          ),
        ),
        const BmoDock(),
      ],
    );
  }
}
