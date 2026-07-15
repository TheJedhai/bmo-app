import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../settings/widgets/settings_modal.dart';
import '../dashboard_registry.dart';
import '../widgets/dash_card.dart';

const _kSpacing = 28.0;
const _kPadding = 28.0;
const _kGearInset = 12.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features = ref.watch(enabledFeaturesProvider);

    final visibleWidgets = dashboardWidgets.where((spec) {
      if (spec.featureKey == null) return true;
      return features.contains(spec.featureKey);
    }).toList();

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
            ),
          ),
          Positioned(
            top: _kGearInset,
            right: _kGearInset,
            child: IconButton(
              icon: const Icon(Icons.settings, color: BmoColors.textSecondary),
              tooltip: 'Configurações',
              onPressed: () => showSettingsModal(context),
            ),
          ),
        ],
      ),
    );
  }
}
