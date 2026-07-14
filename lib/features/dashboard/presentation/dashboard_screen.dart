import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../settings/widgets/settings_modal.dart';
import '../dashboard_registry.dart';
import '../widgets/dash_card.dart';

const _kMobileBreakpoint = 600.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final features = ref.watch(enabledFeaturesProvider);

    final visibleWidgets = dashboardWidgets.where((spec) {
      if (spec.featureKey == null) return true;
      return features.contains(spec.featureKey);
    }).toList();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;

              return Wrap(
                spacing: 28,
                runSpacing: 28,
                alignment: WrapAlignment.center,
                children: visibleWidgets.map((spec) {
                  final cardWidth =
                      isMobile ? availableWidth : spec.width;

                  return SizedBox(
                    width: cardWidth,
                    height: spec.height,
                    child: DashCard(
                      title: spec.title,
                      accent: spec.accent,
                      pulseDelay: spec.pulseDelay,
                      onTap: spec.onTap,
                      child: spec.builder(context, spec.accent),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        // Settings gear — fora do Wrap, canto superior direito.
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.settings, color: BmoColors.textSecondary),
            tooltip: 'Configurações',
            onPressed: () => showSettingsModal(context),
          ),
        ),
      ],
    );
  }
}
