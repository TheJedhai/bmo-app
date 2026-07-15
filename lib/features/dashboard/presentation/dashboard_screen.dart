import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../settings/widgets/settings_modal.dart';
import '../dashboard_registry.dart';
import '../widgets/dash_card.dart';

const _kMobileBreakpoint = 600.0;
const _kMinGap = 24.0;
const _kDefaultCardHeight = 220.0;
const _kDesktopPadding = 28.0;
const _kGearInset = 8.0;

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

    if (isMobile) {
      return _buildMobileLayout(context, visibleWidgets);
    }
    return _buildDesktopLayout(context, visibleWidgets);
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _gearIcon(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings, color: BmoColors.textSecondary),
      tooltip: 'Configurações',
      onPressed: () => showSettingsModal(context),
    );
  }

  Widget _buildCard(
    BuildContext context,
    DashWidgetSpec spec,
    double width,
    double? height,
  ) {
    return SizedBox(
      width: width,
      height: height,
      child: DashCard(
        title: spec.title,
        accent: spec.accent,
        pulseDelay: spec.pulseDelay,
        onTap: spec.onTap,
        child: spec.builder(context, spec.accent),
      ),
    );
  }

  // ── Mobile ──────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    BuildContext context,
    List<DashWidgetSpec> visibleWidgets,
  ) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(_kDesktopPadding),
          child: Column(
            children: visibleWidgets.map((spec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: _kDesktopPadding),
                child: _buildCard(context, spec, double.infinity, spec.height),
              );
            }).toList(),
          ),
        ),
        Positioned(
          top: _kGearInset,
          right: _kGearInset,
          child: _gearIcon(context),
        ),
      ],
    );
  }

  // ── Desktop ─────────────────────────────────────────────────────

  /// Greedy packing: distribui os cards em linhas respeitando a largura
  /// fixa de cada card + um gap mínimo de [_kMinGap].
  List<List<DashWidgetSpec>> _packRows(
    List<DashWidgetSpec> specs,
    double maxWidth,
  ) {
    final rows = <List<DashWidgetSpec>>[];
    List<DashWidgetSpec>? currentRow;
    double currentRowWidth = 0;

    for (final spec in specs) {
      if (currentRow == null) {
        currentRow = [spec];
        currentRowWidth = spec.width;
      } else if (currentRowWidth + _kMinGap + spec.width <= maxWidth) {
        currentRow.add(spec);
        currentRowWidth += _kMinGap + spec.width;
      } else {
        rows.add(currentRow);
        currentRow = [spec];
        currentRowWidth = spec.width;
      }
    }
    if (currentRow != null) rows.add(currentRow);

    return rows;
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    List<DashWidgetSpec> visibleWidgets,
  ) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        final rows = _packRows(visibleWidgets, maxWidth);

        // Constrói cada linha: altura = maior card da linha.
        // Cards sem altura explícita usam _kDefaultCardHeight.
        final rowWidgets = rows.map((row) {
          final rowHeight = row
              .map((s) => s.height ?? _kDefaultCardHeight)
              .reduce((a, b) => a > b ? a : b);

          return SizedBox(
            height: rowHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: row.map((spec) {
                return _buildCard(
                  context,
                  spec,
                  spec.width,
                  rowHeight,
                );
              }).toList(),
            ),
          );
        }).toList();

        // Estima se o conteúdo cabe verticalmente.
        // Se não couber, permite scroll como fallback.
        final totalRowHeight = rows
            .map((r) => r
                .map((s) => s.height ?? _kDefaultCardHeight)
                .reduce((a, b) => a > b ? a : b))
            .fold<double>(0, (a, b) => a + b);
        final needsScroll = totalRowHeight > maxHeight;

        final content = needsScroll
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(_kDesktopPadding),
                child: Column(
                  children: rowWidgets
                      .map((row) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: _kDesktopPadding),
                            child: row,
                          ))
                      .toList(),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(_kDesktopPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: rowWidgets,
                ),
              );

        return Stack(
          children: [
            content,
            Positioned(
              top: _kGearInset,
              right: _kGearInset,
              child: _gearIcon(context),
            ),
          ],
        );
      },
    );
  }
}
