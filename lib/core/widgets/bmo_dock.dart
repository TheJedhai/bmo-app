import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/rss/data/rss_providers.dart';
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

    // Unread count for RSS badge — only watched once at the top so the
    // whole dock rebuilds when it changes.  The badge is specific to the
    // RSS tab today, but a per-tab Map in the future would slot in here.
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

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
                  ? _buildTabIcon(tab.icon, color, tab, unreadCount)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabIcon(tab.icon, color, tab, unreadCount),
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

  /// Builds the tab icon, optionally wrapped with an unread-count badge
  /// for the RSS tab.  Extracted so mobile and desktop layouts share the
  /// same badge logic without duplication.
  Widget _buildTabIcon(
    IconData icon,
    Color color,
    AppTab tab,
    int unreadCount,
  ) {
    final iconWidget = Icon(icon, color: color, size: 24);

    if (tab == AppTab.rss && unreadCount > 0) {
      final label =
          unreadCount > 99 ? '99+' : unreadCount.toString();
      return Badge(
        backgroundColor: BmoColors.accentYellow,
        textColor: BmoColors.screenBg,
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontFamily: 'Inter'),
        ),
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
