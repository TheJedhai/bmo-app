import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/finances_providers.dart';

/// Card da dashboard para a feature Finanças.
///
/// Mostra um resumo rápido: saldo do mês e contagem de reviews pendentes.
class FinancesDashCard extends ConsumerWidget {
  final Color accent;

  const FinancesDashCard({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider);
    final pendingCount = ref.watch(dedupPendingCountProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const _EmptyContent(),
      data: (summary) {
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Saldo do mês
              Row(
                children: [
                  const Text(
                    'Saldo do mês',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: BmoColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: BmoColors.accentRed.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pendingCount dup.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatCurrency(summary.net),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: summary.net >= 0
                      ? BmoColors.accentGreen
                      : BmoColors.accentRed,
                ),
              ),
              const SizedBox(height: 10),
              // Mini barras gastos vs receita
              Row(
                children: [
                  _MiniBar(
                    label: 'Gastos',
                    value: summary.totalSpent.abs(),
                    color: BmoColors.accentRed,
                  ),
                  const SizedBox(width: 12),
                  _MiniBar(
                    label: 'Rec.',
                    value: summary.totalIncome,
                    color: BmoColors.accentGreen,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(double value) {
    final abs = value.abs();
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    final chars = intPart.split('');
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && (chars.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }

    final sign = value < 0 ? '-' : '';
    return '$sign R\$ ${buffer.toString()},$decPart';
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Carregando finanças...',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: BmoColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatShort(value),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatShort(double v) {
    final abs = v.abs();
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    final chars = intPart.split('');
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && (chars.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }
    final sign = v < 0 ? '-' : '';
    return '$sign R\$ ${buffer.toString()},$decPart';
  }
}
