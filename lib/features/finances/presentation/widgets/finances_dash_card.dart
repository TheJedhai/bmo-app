import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../../dashboard/widgets/bmo_density.dart';
import '../../data/finances_providers.dart';
import '../../data/models/summary.dart';

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
        final density = BmoDensity.of(context);

        return Padding(
          padding: const EdgeInsets.all(12),
          child: density.isCompact
              ? _buildCompact(
                  netPosition: summary.netPosition,
                  positionColor: positionColor,
                  checkingBalance: summary.checkingBalance,
                  bill: bill,
                  hasDueDate: hasDueDate,
                )
              : _buildRegular(
                  netPosition: summary.netPosition,
                  positionColor: positionColor,
                  checkingBalance: summary.checkingBalance,
                  bill: bill,
                  hasDueDate: hasDueDate,
                ),
        );
      },
    );
  }

  /// Layout regular (desktop e span-2 do grid): Row com divisória vertical.
  /// Posição à esquerda, Em conta + Fatura à direita.
  Widget _buildRegular({
    required double netPosition,
    required Color positionColor,
    required double checkingBalance,
    required BillInfo? bill,
    required bool hasDueDate,
  }) {
    return IntrinsicHeight(
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
                    _formatCurrency(netPosition),
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
                        _formatCurrency(checkingBalance),
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
    );
  }

  /// Layout compacto (span-1 do grid mobile): pilha vertical. Posição em
  /// destaque no topo; Em conta e Fatura como linhas label-esquerda /
  /// valor-direita, fonte menor, sem divisória. Vencimento da fatura vai na
  /// mesma linha da fatura (FittedBox encolhe se não couber).
  Widget _buildCompact({
    required double netPosition,
    required Color positionColor,
    required double checkingBalance,
    required BillInfo? bill,
    required bool hasDueDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
            _formatCurrency(netPosition),
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
        const SizedBox(height: 14),
        _CompactStatLine(
          label: 'Em conta',
          value: _formatCurrency(checkingBalance),
        ),
        const SizedBox(height: 8),
        _CompactStatLine(
          label: 'Fatura',
          value: bill != null
              ? _formatCurrency(bill.totalAmount)
              : 'sem fatura importada',
          valueColor:
              bill != null ? BmoColors.textPrimary : BmoColors.textMuted,
          trailing: hasDueDate ? _formatDueDate(bill!.dueDate!) : null,
        ),
      ],
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

/// Linha label-esquerda / valor-direita do layout compacto ([_buildCompact]).
///
/// [value] vai à direita dentro de um FittedBox (rede de segurança pra
/// valores longos); [trailing] (ex.: vencimento da fatura) cola no valor e
/// encolhe junto se não couber.
class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor = BmoColors.textPrimary,
  });

  final String label;
  final String value;
  final String? trailing;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: BmoColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    trailing!,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: BmoColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

