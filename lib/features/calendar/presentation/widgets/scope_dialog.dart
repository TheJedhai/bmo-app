import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';

/// Scope for a recurring event operation.
enum RecurrenceScope { this_, all }

/// Shows a dialog asking whether to edit/delete just this occurrence or all.
///
/// [action] is the verb displayed in the prompt (e.g. "editar", "excluir").
/// Returns [RecurrenceScope.this_] or [RecurrenceScope.all], or null if cancelled.
Future<RecurrenceScope?> showScopeDialog(
  BuildContext context, {
  required String action,
}) {
  return showDialog<RecurrenceScope>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      title: const Text(
        'Evento recorrente',
        style: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 13,
          color: BmoColors.textPrimary,
        ),
      ),
      content: Text(
        'Deseja $action só esta ocorrência ou todas as ocorrências da série?',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(RecurrenceScope.this_),
          child: const Text(
            'Só esta',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(RecurrenceScope.all),
          style: TextButton.styleFrom(foregroundColor: BmoColors.accentGreen),
          child: const Text(
            'Todas',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
