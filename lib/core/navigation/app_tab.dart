import 'package:flutter/material.dart';

/// Itens da dock de navegação.
///
/// Mantido após a migração IndexedStack → pushFeature porque o [BmoDock]
/// itera [values] para renderizar os atalhos e mapeia cada entrada para
/// a tela correspondente em [_onDockTap].
enum AppTab {
  home(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  chat(icon: Icons.chat_bubble_outline, label: 'Chat'),
  missions(icon: Icons.task_alt, label: 'Missoes'),
  homeDevices(icon: Icons.lightbulb_outline, label: 'Casa'),
  rss(icon: Icons.rss_feed, label: 'Notícias'),
  vault(icon: Icons.lock_outline, label: 'Cofre');

  const AppTab({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
