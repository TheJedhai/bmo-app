import 'package:flutter/material.dart';

import '../../../../core/theme/bmo_theme.dart';

/// Scope for a recurring event operation.
enum RecurrenceScope { this_, thisAndFuture, all }

/// Shows a dialog asking which occurrences to apply the action to.
///
/// [action] determines the verb in the prompt and which options to show:
/// - 'excluir': "Só esta ocorrência" / "Esta e as futuras" (no "Todas").
/// - 'editar' / 'mover': "Só esta" / "Todas" (unchanged).
///
/// Returns a [RecurrenceScope], or null if cancelled.
Future<RecurrenceScope?> showScopeDialog(
  BuildContext context, {
  required String action,
}) {
  final isDelete = action == 'excluir';

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDelete
                ? 'Deseja excluir só esta ocorrência ou esta e as futuras?'
                : 'Deseja $action só esta ocorrência ou todas as ocorrências da série?',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
          if (isDelete) ...[
            const SizedBox(height: 8),
            Text(
              'As ocorrências passadas serão mantidas.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: BmoColors.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
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
          child: Text(
            isDelete ? 'Só esta ocorrência' : 'Só esta',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
          ),
        ),
        if (isDelete)
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(RecurrenceScope.thisAndFuture),
            style:
                TextButton.styleFrom(foregroundColor: BmoColors.accentGreen),
            child: const Text(
              'Esta e as futuras',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(RecurrenceScope.all),
            style:
                TextButton.styleFrom(foregroundColor: BmoColors.accentGreen),
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
