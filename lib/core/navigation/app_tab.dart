import 'package:flutter/material.dart';

enum AppTab {
  home(icon: Icons.dashboard_outlined, label: 'Dashboard', keepAlive: false),
  chat(icon: Icons.chat_bubble_outline, label: 'Chat', keepAlive: true),
  missions(icon: Icons.task_alt, label: 'Missoes', keepAlive: true),
  homeDevices(icon: Icons.lightbulb_outline, label: 'Casa', keepAlive: true),
  rss(icon: Icons.rss_feed, label: 'Notícias', keepAlive: true),
  vault(icon: Icons.lock_outline, label: 'Cofre', keepAlive: false);

  const AppTab({
    required this.icon,
    required this.label,
    required this.keepAlive,
  });

  final IconData icon;
  final String label;
  final bool keepAlive;
}
