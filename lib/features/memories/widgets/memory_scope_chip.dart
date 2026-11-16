import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';

/// Chip de escopo (leitura): `Pessoal` ou `Da casa`.
class MemoryScopeChip extends StatelessWidget {
  final bool personal;
  const MemoryScopeChip({super.key, required this.personal});

  @override
  Widget build(BuildContext context) {
    final color = personal ? BmoColors.accentYellow : BmoColors.accentBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        personal ? 'Pessoal' : 'Da casa',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BmoColors.textSecondary,
          height: 1.2,
        ),
      ),
    );
  }
}
