import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/app_tab.dart';
import '../navigation/tab_provider.dart';
import '../theme/bmo_theme.dart';

class BmoDock extends ConsumerWidget {
  const BmoDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: AppTab.values.map((tab) {
          final isActive = tab == currentTab;
          final color = isActive ? BmoColors.accentGreen : BmoColors.textMuted;

          return InkWell(
            onTap: () => ref.read(currentTabProvider.notifier).setTab(tab),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
