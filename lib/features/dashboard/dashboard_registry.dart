import 'package:flutter/material.dart';

import 'widgets/clock_card.dart';

/// Especificação de um widget da dashboard.
///
/// [featureKey] null = visível para todos os usuários.
/// [featureKey] preenchido = só renderiza se a key estiver em
/// [enabledFeaturesProvider].
class DashWidgetSpec {
  final String id;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final String? featureKey;
  final WidgetBuilder builder;

  const DashWidgetSpec({
    required this.id,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    this.featureKey,
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
];

Widget _clockCardBuilder(BuildContext context) {
  return const ClockCard();
}
