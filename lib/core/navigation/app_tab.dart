import 'package:flutter/material.dart';

/// Itens da dock de navegação.
///
/// O [BmoDock] itera [values] para renderizar os atalhos e mapeia cada
/// entrada para uma rota do go_router. As extensões [AppTabPath] e
/// [AppTabLookup] centralizam o mapeamento tab ↔ path.
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

// ---------------------------------------------------------------------------
// Route mapping
// ---------------------------------------------------------------------------

/// Maps each [AppTab] to its go_router path.
extension AppTabPath on AppTab {
  String get path {
    return switch (this) {
      AppTab.home => '/',
      AppTab.chat => '/chat',
      AppTab.missions => '/missoes',
      AppTab.homeDevices => '/casa',
      AppTab.rss => '/noticias',
      AppTab.vault => '/cofre',
    };
  }
}

/// Resolves a go_router path string back to an [AppTab] (defaults to
/// [AppTab.home] for unknown paths).
extension AppTabLookup on AppTab {
  static AppTab fromPath(String path) {
    return AppTab.values.firstWhere(
      (tab) => tab.path == path,
      orElse: () => AppTab.home,
    );
  }
}
