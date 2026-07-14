import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_tab.dart';
import '../../core/navigation/tab_provider.dart';
import '../../core/theme/bmo_theme.dart';
import '../gallery/widgets/gallery_modal.dart';
import 'widgets/clock_card.dart';
import 'widgets/gallery_card.dart';
import 'widgets/lights_card.dart';
import 'widgets/missions_card.dart';
import 'widgets/rss_card.dart';

/// Especificação de um widget da dashboard.
///
/// Cada card tem largura fixa ([width]), altura opcional ([height] null =
/// altura pelo conteúdo), e um [accent] que define cor da borda, glow e
/// destaques internos.
///
/// [featureKey] null = visível para todos os usuários.
/// [featureKey] preenchido = só renderiza se a key estiver em
/// [enabledFeaturesProvider].
///
/// [onTap] opcional: se presente, o [DashCard] recebe o callback e
/// mostra chevron no header.
///
/// [pulseDelay] define o atraso inicial da animação de glow.
class DashWidgetSpec {
  final String id;
  final String title;
  final Color accent;
  final double width;
  final double? height;
  final Duration pulseDelay;
  final String? featureKey;
  final void Function(BuildContext)? onTap;
  final Widget Function(BuildContext context, Color accent) builder;

  const DashWidgetSpec({
    required this.id,
    required this.title,
    required this.accent,
    required this.width,
    this.height,
    this.pulseDelay = Duration.zero,
    this.featureKey,
    this.onTap,
    required this.builder,
  });
}

/// Lista ordenada de widgets da dashboard.
///
/// A ordem da lista é a ordem de renderização — para reordenar cards,
/// mover a entrada de posição.
final List<DashWidgetSpec> dashboardWidgets = [
  const DashWidgetSpec(
    id: 'relogio',
    title: 'Relógio',
    accent: BmoColors.accentYellow,
    width: 400,
    builder: _clockCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'missoes',
    title: 'Missões',
    accent: BmoColors.accentGreen,
    width: 340,
    pulseDelay: Duration(milliseconds: 500),
    onTap: _goToMissions,
    builder: _missionsCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'noticias',
    title: 'Notícias',
    accent: BmoColors.accentBlue,
    width: 340,
    pulseDelay: Duration(milliseconds: 1000),
    onTap: _goToRss,
    builder: _rssCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'casa',
    title: 'Casa',
    accent: BmoColors.accentRed,
    width: 300,
    pulseDelay: Duration(milliseconds: 1500),
    onTap: _goToHomeDevices,
    builder: _lightsCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'galeria',
    title: 'Galeria',
    accent: BmoColors.accentRed,
    width: 400,
    height: 220,
    pulseDelay: Duration(milliseconds: 2000),
    onTap: showGalleryModal,
    builder: _galleryCardBuilder,
  ),
];

void _goToMissions(BuildContext context) {
  ProviderScope.containerOf(context)
      .read(currentTabProvider.notifier)
      .setTab(AppTab.missions);
}

void _goToRss(BuildContext context) {
  ProviderScope.containerOf(context)
      .read(currentTabProvider.notifier)
      .setTab(AppTab.rss);
}

void _goToHomeDevices(BuildContext context) {
  ProviderScope.containerOf(context)
      .read(currentTabProvider.notifier)
      .setTab(AppTab.homeDevices);
}

Widget _clockCardBuilder(BuildContext context, Color accent) {
  return ClockCard(accent: accent);
}

Widget _missionsCardBuilder(BuildContext context, Color accent) {
  return MissionsCard(accent: accent);
}

Widget _rssCardBuilder(BuildContext context, Color accent) {
  return RssCard(accent: accent);
}

Widget _lightsCardBuilder(BuildContext context, Color accent) {
  return LightsCard(accent: accent);
}

Widget _galleryCardBuilder(BuildContext context, Color accent) {
  return GalleryCard(accent: accent);
}
