import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/coding_run.dart';

/// Aparência de um status de run: rótulo pt-BR, ícone e cor. Compartilhado
/// pelo card rico, pela lista do projeto e pelo detalhe.
({String label, IconData icon, Color color}) codingRunLook(
  CodingRunStatus status,
) => switch (status) {
  CodingRunStatus.queued => (
    label: 'na fila',
    icon: Icons.schedule,
    color: BmoColors.accentYellow,
  ),
  CodingRunStatus.running => (
    label: 'rodando',
    icon: Icons.autorenew,
    color: BmoColors.accentYellow,
  ),
  CodingRunStatus.success => (
    label: 'sucesso',
    icon: Icons.check,
    color: BmoColors.accentGreen,
  ),
  CodingRunStatus.failed => (
    label: 'falha',
    icon: Icons.close,
    color: BmoColors.accentRed,
  ),
  CodingRunStatus.timeout => (
    label: 'tempo esgotado',
    icon: Icons.hourglass_bottom,
    color: BmoColors.accentRed,
  ),
  CodingRunStatus.killed => (
    label: 'parado',
    icon: Icons.block,
    color: BmoColors.textSecondary,
  ),
};

/// Ícone com spinner enquanto na fila/rodando.
class CodingRunStatusIcon extends StatelessWidget {
  final CodingRunStatus status;
  final double size;

  const CodingRunStatusIcon({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final look = codingRunLook(status);
    final active =
        status == CodingRunStatus.queued || status == CodingRunStatus.running;
    if (!active) {
      return Icon(look.icon, size: size, color: look.color);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: look.color),
    );
  }
}

/// Quando o run aconteceu, com o mesmo formato relativo das telas de coding.
String formatRunTimestamp(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
  if (diff.inHours < 24) return '${diff.inHours}h atrás';
  final d = when.day.toString().padLeft(2, '0');
  final m = when.month.toString().padLeft(2, '0');
  return '$d/$m';
}
