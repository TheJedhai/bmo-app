import 'package:flutter/material.dart';

enum AppTab {
  home(icon: Icons.home_outlined, label: 'Home', keepAlive: false),
  chat(icon: Icons.chat_bubble_outline, label: 'Chat', keepAlive: true),
  missions(icon: Icons.task_alt, label: 'Missoes', keepAlive: true),
  homeDevices(icon: Icons.lightbulb_outline, label: 'Casa', keepAlive: true);

  const AppTab({
    required this.icon,
    required this.label,
    required this.keepAlive,
  });

  final IconData icon;
  final String label;
  final bool keepAlive;
}
