import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/identity/identity_state.dart';
import '../../../core/identity/user_profile.dart';
import '../../../core/identity/widgets/profile_avatar.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../features/settings/widgets/settings_modal.dart';
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
        final crossAxisCount =
            (constraints.maxWidth / 380).floor().clamp(1, 4);

        return MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: _kSpacing,
          crossAxisSpacing: _kSpacing,
          padding: const EdgeInsets.all(_kPadding),
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
              return SizedBox(
                height: spec.height,
                child: card,
              );
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
/// 1. Header full-width com relógio + data + saudação (esquerda) e
///    controles (engrenagem + avatar) à direita.
/// 2. MasonryGridView de 2 colunas com os cards restantes.
class _DashboardMobileLayout extends ConsumerWidget {
  const _DashboardMobileLayout({required this.visibleWidgets});

  final List<DashWidgetSpec> visibleWidgets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Separa o relógio dos cards
    final clockSpec =
        visibleWidgets.where((s) => s.id == 'relogio').firstOrNull;
    final cardSpecs =
        visibleWidgets.where((s) => s.id != 'relogio').toList();

    final userAsync = ref.watch(currentUserProvider);

    return Column(
      children: [
        // ---- Header ----
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _kMobilePadding,
            _kMobilePadding,
            _kMobilePadding,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Relógio + data + saudação
              Expanded(
                child: _MobileClockContent(
                  accent: clockSpec?.accent ?? BmoColors.accentYellow,
                ),
              ),
              const SizedBox(width: 12),
              // Controles: engrenagem + avatar
              _MobileControls(userAsync: userAsync),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ---- Grid de cards (2 colunas) ----
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
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
/// Mostra hora (PressStart2P 36px), data por extenso (Inter 13px) e saudação
/// com nome do usuário (Inter 14px). O timer atualiza a cada minuto.
class _MobileClockContent extends ConsumerStatefulWidget {
  const _MobileClockContent({required this.accent});

  final Color accent;

  @override
  ConsumerState<_MobileClockContent> createState() =>
      _MobileClockContentState();
}

class _MobileClockContentState extends ConsumerState<_MobileClockContent> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _greeting(int hour) {
    if (hour >= 6 && hour < 12) return 'Bom dia,';
    if (hour >= 12 && hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
  }

  @override
  Widget build(BuildContext context) {
    final hourFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat.yMMMMEEEEd('pt_BR');
    final hour = _now.hour;

    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.whenOrNull(data: (u) => u?.name) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hora
        Text(
          hourFormat.format(_now),
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 36,
            color: widget.accent,
            shadows: [
              Shadow(
                color: widget.accent.withValues(alpha: 0.40),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Data
        Text(
          dateFormat.format(_now),
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
                text: '${_greeting(hour)} ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
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

// ============================================================================
// Header mobile — controles
// ============================================================================

/// Engrenagem (settings) e avatar (perfil) no canto direito do header mobile.
///
/// Cada controle tem hitbox de 48×48px.
class _MobileControls extends StatelessWidget {
  const _MobileControls({required this.userAsync});

  final AsyncValue<UserProfile?> userAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Engrenagem
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showSettingsModal(context),
              borderRadius: BorderRadius.circular(24),
              child: const Icon(
                Icons.settings,
                size: 24,
                color: BmoColors.accentGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Avatar
        SizedBox(
          width: 48,
          height: 48,
          child: userAsync.whenOrNull(
                data: (user) {
                  if (user == null) return const SizedBox.shrink();
                  return Consumer(
                    builder: (context, ref, _) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => ref
                              .read(currentUserProvider.notifier)
                              .clearUser(),
                          borderRadius: BorderRadius.circular(24),
                          child: ProfileAvatar(profile: user, radius: 18),
                        ),
                      );
                    },
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ),
      ],
    );
  }
}
