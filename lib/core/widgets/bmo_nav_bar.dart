import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_registry.dart';
import '../../features/rss/data/rss_providers.dart';
import '../identity/identity_provider.dart';
import '../identity/identity_state.dart';
import '../theme/bmo_theme.dart';

/// Item da nav bar ativo também nas sub-rotas do item.
///
/// `/coding` fica ativo em `/coding/4`, `/coding/4/chat` e
/// `/coding/runs/42`. A raiz `/` (dashboard) só casa exata — prefixo ali
/// marcaria tudo.
bool navRouteIsActive(String route, String location) {
  if (route == '/') return location == '/';
  return location == route || location.startsWith('$route/');
}

/// Barra de navegação inferior flutuante — pílula compacta só com ícones.
///
/// Flutua acima da borda inferior da tela, centralizada horizontalmente.
/// Itera [dashboardWidgets] com [DashWidgetSpec.showInNavBar] == true.
///
/// Badge de não lidos: RSS vem de [unreadCountProvider]; Chat e Coding do
/// `unread` do `/api/v1/me` ([unreadBadgesProvider]).
/// O ícone da rota atual fica em [BmoColors.accentGreen]; os demais em
/// [BmoColors.textMuted]. Tap usa [GoRouter.go] para substituir em vez
/// de empilhar.
class BmoNavBar extends ConsumerWidget {
  const BmoNavBar({super.key, required this.currentLocation});

  /// Altura total da pílula + margem inferior — usada como padding-bottom
  /// no conteúdo das features para evitar sobreposição.
  static const double totalBottomInset = 68 + 16;

  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesProvider);
    final rssUnread = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final unread = ref.watch(unreadBadgesProvider).valueOrNull ??
        UnreadCounts.none;

    final navSpecs = dashboardWidgets.where((s) {
      if (!s.showInNavBar) return false;
      if (s.featureKey == null) return true;
      return features.contains(s.featureKey);
    }).toList();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: BmoColors.screenBgElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: BmoColors.accentGreen.withAlpha(30),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: BmoColors.accentGreen.withAlpha(15),
                blurRadius: 24,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final spec in navSpecs) ...[
                _NavBarItem(
                  spec: spec,
                  badgeCount: _badgeCount(spec.id, rssUnread, unread),
                  isActive: navRouteIsActive(spec.route!, currentLocation),
                  onTap: () {
                    // Sempre vai para a raiz do item quando a rota atual é
                    // outra (mesmo que o item esteja marcado como ativo por
                    // estar numa sub-rota). Tocar de novo na raiz não faz nada.
                    if (currentLocation == spec.route) return;
                    GoRouter.of(context).go(spec.route!);
                  },
                ),
                if (spec != navSpecs.last)
                  const SizedBox(width: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantos não lidos mostrar no item: RSS, Chat (`unread.chat`) ou Coding
/// (`unread.coding`).
int _badgeCount(String id, int rssUnread, UnreadCounts unread) => switch (id) {
      'noticias' => rssUnread,
      'chat' => unread.chatAndDaily,
      'coding' => unread.coding,
      _ => 0,
    };

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.spec,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
  });

  final DashWidgetSpec spec;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    assert(
      spec.navIcon != null && spec.route != null,
      'DashWidgetSpec "${spec.id}" has showInNavBar=true but navIcon or route is null',
    );

    final color = isActive ? BmoColors.accentGreen : BmoColors.textMuted;

    final icon = SizedBox.square(
      dimension: 40,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(spec.navIcon, color: color, size: 22),
        tooltip: spec.title,
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );

    // Badge discreto de não lidos no canto superior direito do ícone.
    if (badgeCount <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -2,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 15),
            height: 15,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: BmoColors.accentRed,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: BmoColors.textPrimary,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
