import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/finances_providers.dart';

/// Card da dashboard para a feature Finanças.
///
/// Mostra posição líquida (net_position), saldo em conta e fatura do cartão.
class FinancesDashCard extends ConsumerWidget {
  final Color accent;

  const FinancesDashCard({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider);

    return summaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const _EmptyContent(),
      data: (summary) {
        final isPositive = summary.netPosition >= 0;
        final positionColor =
            isPositive ? BmoColors.accentGreen : BmoColors.accentRed;
        final bill = summary.openBill;
        final hasDueDate = bill?.dueDate != null;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Metade esquerda — Posição, centralizada verticalmente
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Posição',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatCurrency(summary.netPosition),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: positionColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Divisor vertical sutil
              const SizedBox(width: 12),
              Container(
                width: 1,
                color: BmoColors.textMuted.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 12),
              // Metade direita — Em conta + Fatura
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Em conta',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: BmoColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _formatCurrency(summary.checkingBalance),
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: BmoColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Fatura',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: BmoColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            bill != null
                                ? _formatCurrency(bill.totalAmount)
                                : 'sem fatura importada',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: bill != null
                                  ? BmoColors.textPrimary
                                  : BmoColors.textMuted,
                            ),
                          ),
                        ),
                        if (hasDueDate) ...[
                          const SizedBox(height: 1),
                          Text(
                            _formatDueDate(bill!.dueDate!),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: BmoColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  /// Converte due_date (YYYY-MM-DD) para "dd/MM".
  String _formatDueDate(String isoDate) {
    try {
      final parts = isoDate.split('-');
      if (parts.length == 3) {
        return 'vence ${parts[2]}/${parts[1]}';
      }
    } catch (_) {}
    return isoDate;
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

