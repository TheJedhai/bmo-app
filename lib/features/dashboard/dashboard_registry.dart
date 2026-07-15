import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/bmo_theme.dart';
import '../gallery/widgets/gallery_modal.dart';
import 'widgets/chat_card.dart';
import 'widgets/clock_card.dart';
import 'widgets/gallery_card.dart';
import 'widgets/lights_card.dart';
import 'widgets/missions_card.dart';
import 'widgets/rss_card.dart';
import 'widgets/vault_card.dart';

/// Especificação de um widget da dashboard.
///
/// A largura é definida pelo masonry layout (número de colunas responsivo).
/// Altura opcional ([height] null = altura intrínseca pelo conteúdo).
/// [accent] define cor da borda, glow e destaques internos.
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
  final double? height;
  final Duration pulseDelay;
  final String? featureKey;
  final void Function(BuildContext)? onTap;
  final Widget Function(BuildContext context, Color accent) builder;

  const DashWidgetSpec({
    required this.id,
    required this.title,
    required this.accent,
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
    builder: _clockCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'missoes',
    title: 'Missões',
    accent: BmoColors.accentGreen,
    pulseDelay: Duration(milliseconds: 500),
    onTap: _goToMissions,
    builder: _missionsCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'noticias',
    title: 'Notícias',
    accent: BmoColors.accentBlue,
    pulseDelay: Duration(milliseconds: 1000),
    onTap: _goToRss,
    builder: _rssCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'casa',
    title: 'Casa',
    accent: BmoColors.accentRed,
    pulseDelay: Duration(milliseconds: 1500),
    onTap: _goToHomeDevices,
    builder: _lightsCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'galeria',
    title: 'Galeria',
    accent: BmoColors.accentRed,
    height: 220,
    pulseDelay: Duration(milliseconds: 2000),
    onTap: showGalleryModal,
    builder: _galleryCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'chat',
    title: 'Chat',
    accent: BmoColors.accentGreen,
    pulseDelay: Duration(milliseconds: 2500),
    onTap: _goToChat,
    builder: _chatCardBuilder,
  ),
  const DashWidgetSpec(
    id: 'cofre',
    title: 'Cofre',
    accent: BmoColors.accentYellow,
    pulseDelay: Duration(milliseconds: 3000),
    onTap: _goToVault,
    builder: _vaultCardBuilder,
  ),
];

void _goToMissions(BuildContext context) {
  context.push('/missoes');
}

void _goToRss(BuildContext context) {
  context.push('/noticias');
}

void _goToHomeDevices(BuildContext context) {
  context.push('/casa');
}

void _goToChat(BuildContext context) {
  context.push('/chat');
}

void _goToVault(BuildContext context) {
  context.push('/cofre');
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

Widget _chatCardBuilder(BuildContext context, Color accent) {
  return ChatCard(accent: accent);
}

Widget _vaultCardBuilder(BuildContext context, Color accent) {
  return VaultCard(accent: accent);
}
