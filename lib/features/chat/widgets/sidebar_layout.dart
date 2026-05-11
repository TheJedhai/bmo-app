import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../providers/chat_providers.dart';
import 'conversation_list.dart';

const _kMobileBreakpoint = 600.0;
const _kSidebarWidth = 260.0;

class SidebarLayout extends ConsumerWidget {
  final Widget child;
  const SidebarLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    if (isMobile) {
      return _MobileLayout(child: child);
    }
    return _DesktopLayout(child: child);
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget child;
  const _DesktopLayout({required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          width: _kSidebarWidth,
          child: ConversationList(),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: BmoColors.textMuted.withValues(alpha: 0.2),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _MobileLayout extends ConsumerWidget {
  final Widget child;
  const _MobileLayout({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedConversationIdProvider);
    final convs = ref.watch(conversationsProvider).valueOrNull ?? const [];
    final selected = selectedId == null
        ? null
        : convs.where((c) => c.uuid == selectedId).cast<dynamic>().firstOrNull;
    final title = selected?.name as String? ?? 'BMO';

    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: Drawer(
        backgroundColor: BmoColors.screenBg,
        child: ConversationList(
          onItemTap: () {
            // Fecha o drawer ao selecionar/criar.
            Navigator.of(context).pop();
          },
        ),
      ),
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            color: BmoColors.textPrimary,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          title.isEmpty ? 'BMO' : title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: BmoColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: child,
    );
  }
}
