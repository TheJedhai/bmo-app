import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import 'conversation_list.dart';

const _kMobileBreakpoint = 600.0;
const _kSidebarWidth = 260.0;

/// Layout adaptativo para o chat.
///
/// Desktop: sidebar fixa com [ConversationList] à esquerda + [child].
/// Mobile: apenas [child] — o Scaffold/AppBar/drawer ficam a cargo
/// do widget pai (ChatScreen), que precisa de controle sobre o drawer.
class SidebarLayout extends ConsumerWidget {
  final Widget child;
  const SidebarLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    if (isMobile) return child;

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
