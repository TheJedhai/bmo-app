import 'package:flutter/material.dart';

import 'widgets/clock_card.dart';
import 'widgets/missions_card.dart';

/// Especificação de um widget da dashboard.
///
/// [featureKey] null = visível para todos os usuários.
/// [featureKey] preenchido = só renderiza se a key estiver em
/// [enabledFeaturesProvider].
///
/// [onTap] opcional: se presente, o [DashCard] recebe o callback e
/// mostra chevron no header.
class DashWidgetSpec {
  final String id;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final String? featureKey;
  final VoidCallback? onTap;
  final WidgetBuilder builder;

  const DashWidgetSpec({
    required this.id,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    this.featureKey,
    this.onTap,
    required this.builder,
  });
}

/// Lista ordenada de widgets da dashboard.
///
/// Cada spec define tamanho (em células do StaggeredGrid), visibilidade
/// condicional via [featureKey], e o builder do conteúdo.
///
/// Adicione novas specs aqui para registrar widgets na dashboard.
final List<DashWidgetSpec> dashboardWidgets = [
  const DashWidgetSpec(
    id: 'Relógio',
    crossAxisCellCount: 2,
    mainAxisCellCount: 1,
    builder: _clockCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'Missões',
    crossAxisCellCount: 2,
    mainAxisCellCount: 2,
    builder: _missionsCardBuilder,
  ),
];

Widget _clockCardBuilder(BuildContext context) {
  return const ClockCard();
}

Widget _missionsCardBuilder(BuildContext context) {
  return const MissionsCard();
}
