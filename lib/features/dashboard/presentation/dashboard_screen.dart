import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../core/time/current_minute_provider.dart';
import '../dashboard_registry.dart';
import '../widgets/dash_card.dart';

const _kMobileBreakpoint = 600.0;
const _kSpacing = 28.0;
const _kPadding = 28.0;
const _kMobilePadding = 16.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesProvider);

    final visibleWidgets = dashboardWidgets.where((spec) {
      if (spec.featureKey == null) return true;
      return features.contains(spec.featureKey);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _kMobileBreakpoint;

        if (isMobile) {
          return _DashboardMobileLayout(visibleWidgets: visibleWidgets);
        }

        // ---- Desktop ----
        final crossAxisCount = (constraints.maxWidth / 380).floor().clamp(1, 4);

        return MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: _kSpacing,
          crossAxisSpacing: _kSpacing,
          padding: const EdgeInsets.all(_kPadding),
          clipBehavior: Clip.none,
          itemCount: visibleWidgets.length,
          itemBuilder: (context, index) {
            final spec = visibleWidgets[index];
            final card = DashCard(
              title: spec.title,
              accent: spec.accent,
              pulseDelay: spec.pulseDelay,
              onTap: spec.onTap,
              child: spec.builder(context, spec.accent),
            );

            if (spec.height != null) {
              return SizedBox(height: spec.height, child: card);
            }
            return card;
          },
        );
      },
    );
  }
}

// ============================================================================
// Mobile layout
// ============================================================================

/// Layout mobile da dashboard:
/// 1. Header full-width com relógio + data + saudação.
///    (Controles ficam no BmoTopBar, fora da dashboard.)
/// 2. MasonryGridView de 2 colunas com os cards restantes.
class _DashboardMobileLayout extends ConsumerWidget {
  const _DashboardMobileLayout({required this.visibleWidgets});

  final List<DashWidgetSpec> visibleWidgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Separa o relógio dos cards
    final clockSpec = visibleWidgets
        .where((s) => s.id == 'relogio')
        .firstOrNull;
    final cardSpecs = visibleWidgets.where((s) => s.id != 'relogio').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Header ----
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _kMobilePadding,
            _kMobilePadding,
            _kMobilePadding,
            0,
          ),
          child: _MobileClockContent(
            accent: clockSpec?.accent ?? BmoColors.accentYellow,
          ),
        ),
        const SizedBox(height: 16),
        // ---- Grid de cards (2 colunas) ----
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(
              _kMobilePadding,
              0,
              _kMobilePadding,
              _kMobilePadding,
            ),
            itemCount: cardSpecs.length,
            itemBuilder: (context, index) {
              final spec = cardSpecs[index];
              final card = DashCard(
                title: spec.title,
                accent: spec.accent,
                pulseDelay: spec.pulseDelay,
                onTap: spec.onTap,
                child: spec.builder(context, spec.accent),
              );

              if (spec.height != null) {
                return SizedBox(height: spec.height, child: card);
              }
              return card;
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Header mobile — relógio
// ============================================================================

/// Conteúdo do relógio para o header mobile, extraído do [ClockCard].
///
/// Mostra hora (PressStart2P 36px), data curta "qui, 21 ago" (Inter 13px)
/// e saudação com nome do usuário (Inter 14px). A hora vem do
/// [currentMinuteProvider] — atualiza a cada minuto alinhado e sobrevive
/// à suspensão do iOS via AppLifecycleListener.
class _MobileClockContent extends ConsumerWidget {
  const _MobileClockContent({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentMinuteProvider);
    // pt_BR renderiza "qui., 21 ago."; sem os pontos fica "qui, 21 ago".
    final date = DateFormat('EEE, d MMM', 'pt_BR')
        .format(now)
        .replaceAll('.', '');
    final hour = now.hour;

    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.whenOrNull(data: (u) => u?.name) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hora — height 1.0 compensa o ascent/descent da PressStart2P
        // (linha box alta demais); FittedBox encolhe se a largura faltar.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            hourFormatter.format(now),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 36,
              height: 1.0,
              color: accent,
              shadows: [
                Shadow(
                  color: accent.withValues(alpha: 0.40),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Data curta
        Text(
          date,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        // Saudação
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textPrimary,
            ),
            children: [
              TextSpan(
                text: '${greetingForHour(hour)} ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              TextSpan(text: userName),
            ],
          ),
        ),
      ],
    );
  }
}
