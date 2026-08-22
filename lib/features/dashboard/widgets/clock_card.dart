import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/identity/identity_provider.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../core/time/current_minute_provider.dart';

/// Relógio + data + saudação (desktop).
///
/// Mostra a hora em PressStart2P 44px na cor do accent, data por extenso
/// em pt-BR e saudação por período do dia com nome do usuário. A hora vem
/// do [currentMinuteProvider] — atualiza a cada minuto alinhado.
class ClockCard extends ConsumerWidget {
  const ClockCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(currentMinuteProvider);
    final dateFormat = DateFormat.yMMMMEEEEd('pt_BR');
    final hour = now.hour;

    final userAsync = ref.watch(currentUserProvider);
    final userName = userAsync.whenOrNull(data: (u) => u?.name) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hora em destaque
        Text(
          hourFormatter.format(now),
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 44,
            color: accent,
            shadows: [
              Shadow(
                color: accent.withValues(alpha: 0.40),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Data por extenso
        Text(
          dateFormat.format(now),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // Saudação + nome
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: BmoColors.textPrimary,
            ),
            children: [
              TextSpan(
                text: '${greetingForHour(hour)} ',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              TextSpan(text: userName),
            ],
          ),
        ),
      ],
    );
  }
}
