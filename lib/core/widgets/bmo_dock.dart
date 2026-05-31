import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../navigation/app_tab.dart';
import '../navigation/tab_provider.dart';
import '../theme/bmo_theme.dart';

const _kMobileBreakpoint = 600.0;

class BmoDock extends ConsumerWidget {
  const BmoDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

    return Container(
      height: isMobile ? 56 : 64,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: AppTab.values.map((tab) {
          final isActive = tab == currentTab;
          final color = isActive ? BmoColors.accentGreen : BmoColors.textMuted;

          return InkWell(
            onTap: () => ref.read(currentTabProvider.notifier).setTab(tab),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 8,
              ),
              child: isMobile
                  ? Icon(tab.icon, color: color, size: 24)
                  : Column(
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
