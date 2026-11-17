import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/coding_task.dart';

/// Aparência de um status de tarefa: rótulo pt-BR, ícone e cor. Compartilhado
/// pelo card rico, pela lista do projeto e pelo detalhe.
({String label, IconData icon, Color color}) codingTaskLook(
  CodingTaskStatus status,
) => switch (status) {
  CodingTaskStatus.draft => (
    label: 'rascunho',
    icon: Icons.edit_note,
    color: BmoColors.textSecondary,
  ),
  CodingTaskStatus.awaitingApproval => (
    label: 'aguardando aprovação',
    icon: Icons.hourglass_top,
    color: BmoColors.accentYellow,
  ),
  CodingTaskStatus.running => (
    label: 'executando',
    icon: Icons.autorenew,
    color: BmoColors.accentYellow,
  ),
  CodingTaskStatus.readyToJoin => (
    label: 'pronta para juntar',
    icon: Icons.merge_type,
    color: BmoColors.accentGreen,
  ),
  CodingTaskStatus.joined => (
    label: 'juntada',
    icon: Icons.check,
    color: BmoColors.accentGreen,
  ),
  CodingTaskStatus.blocked => (
    label: 'bloqueada',
    icon: Icons.error_outline,
    color: BmoColors.accentRed,
  ),
  CodingTaskStatus.cancelled => (
    label: 'cancelada',
    icon: Icons.block,
    color: BmoColors.textMuted,
  ),
};

/// Aparência do status de um passo.
({String label, IconData icon, Color color}) codingStepLook(
  CodingStepStatus status,
) => switch (status) {
  CodingStepStatus.pending => (
    label: 'pendente',
    icon: Icons.radio_button_unchecked,
    color: BmoColors.textMuted,
  ),
  CodingStepStatus.running => (
    label: 'executando',
    icon: Icons.autorenew,
    color: BmoColors.accentYellow,
  ),
  CodingStepStatus.reviewing => (
    label: 'revisando',
    icon: Icons.rate_review_outlined,
    color: BmoColors.accentYellow,
  ),
  CodingStepStatus.done => (
    label: 'feito',
    icon: Icons.check,
    color: BmoColors.accentGreen,
  ),
  CodingStepStatus.failed => (
    label: 'falhou',
    icon: Icons.close,
    color: BmoColors.accentRed,
  ),
};

/// Ícone do status da tarefa, com spinner enquanto ela executa.
class CodingTaskStatusIcon extends StatelessWidget {
  final CodingTaskStatus status;
  final double size;

  const CodingTaskStatusIcon({super.key, required this.status, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final look = codingTaskLook(status);
    if (status != CodingTaskStatus.running) {
      return Icon(look.icon, size: size, color: look.color);
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: look.color),
    );
  }
}

/// "passo 2/5" (ou "0/5" antes do primeiro passo).
String formatStepProgress(int current, int total) =>
    'passo $current/$total';
