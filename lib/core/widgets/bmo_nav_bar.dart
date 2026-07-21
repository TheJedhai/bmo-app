import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_registry.dart';
import '../../features/rss/data/rss_providers.dart';
import '../theme/bmo_theme.dart';

/// Barra de navegação inferior flutuante — pílula compacta só com ícones.
///
/// Flutua acima da borda inferior da tela, centralizada horizontalmente.
/// Itera [dashboardWidgets] com [DashWidgetSpec.showInNavBar] == true.
/// O ícone da rota atual fica em [BmoColors.accentGreen]; os demais em
/// [BmoColors.textMuted]. Tap usa [GoRouter.go] para substituir em vez
/// de empilhar.
class BmoNavBar extends ConsumerWidget {
  const BmoNavBar({super.key});

  /// Altura total da pílula + margem inferior — usada como padding-bottom
  /// no conteúdo das features para evitar sobreposição.
  static const double totalBottomInset = 68 + 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    final currentLocation = router.state.uri.path;

    final navSpecs = dashboardWidgets
        .where((s) => s.showInNavBar)
        .toList();

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
                  isActive: currentLocation == spec.route,
                  onTap: () {
                    if (currentLocation == spec.route) return;
                    router.go(spec.route!);
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

class _NavBarItem extends ConsumerWidget {
  const _NavBarItem({
    required this.spec,
    required this.isActive,
    required this.onTap,
  });

  final DashWidgetSpec spec;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Badge discreto de não lidos no canto superior direito do ícone
    if (spec.id == 'noticias') {
      final unreadAsync = ref.watch(unreadCountProvider);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          unreadAsync.whenOrNull(
            data: (count) {
              if (count <= 0) return const SizedBox.shrink();
              return Positioned(
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
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: BmoColors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      );
    }

    return icon;
  }
}
