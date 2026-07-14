import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    final crossAxisCount = isMobile ? 2 : 4;
    final features = ref.watch(enabledFeaturesProvider);

    final visibleWidgets = dashboardWidgets.where((spec) {
      if (spec.featureKey == null) return true;
      return features.contains(spec.featureKey);
    }).toList();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StaggeredGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: visibleWidgets.map((spec) {
              final clampedCross = isMobile
                  ? spec.crossAxisCellCount.clamp(1, 2)
                  : spec.crossAxisCellCount;
              return StaggeredGridTile.count(
                crossAxisCellCount: clampedCross,
                mainAxisCellCount: spec.mainAxisCellCount,
                child: DashCard(
                  title: spec.id,
                  child: spec.builder(context),
                ),
              );
            }).toList(),
          ),
        ),
        // Settings gear — fora do grid, canto superior direito.
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
