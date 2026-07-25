import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/finances_providers.dart';
import '../../data/models/summary.dart';
import 'transaction_list_sheet.dart';

/// Bloco do topo: seletor de mês + cards de saldo, fatura, dívida e posição.
class SummarySection extends ConsumerWidget {
  const SummarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(summaryMonthRangeProvider);
    final summaryAsync = ref.watch(summaryProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(range.from);

    return Column(
      children: [
        // Seletor de mês
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _MonthButton(
                icon: Icons.chevron_left,
                onTap: () => _changeMonth(ref, -1),
              ),
              const SizedBox(width: 12),
              Text(
                monthLabel[0].toUpperCase() + monthLabel.substring(1),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BmoColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              _MonthButton(
                icon: Icons.chevron_right,
                onTap: () => _changeMonth(ref, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Cards de resumo
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox.shrink(),
          data: (summary) {
            void openFlowSheet(String flow, String title) {
              final totalFormatted = currencyFormat.format(
                flow == 'expense'
                    ? summary.totalSpent.abs()
                    : summary.totalIncome,
              );
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => TransactionListSheet(
                  title: '$title  •  $totalFormatted',
                  flow: flow,
                  from: range.from,
                  to: range.to,
                ),
              );
            }

            final netPositionColor = summary.netPosition >= 0
                ? BmoColors.accentGreen
                : BmoColors.accentRed;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Row 1: Saldo em conta + Posição
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Saldo em conta',
                          value: currencyFormat
                              .format(summary.checkingBalance),
                          color: BmoColors.accentGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Posição',
                          value: currencyFormat
                              .format(summary.netPosition),
                          color: netPositionColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Fatura em aberto + Resumo do mês
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _BillCard(bill: summary.openBill),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CompactFlowCard(
                            spent: summary.totalSpent.abs(),
                            income: summary.totalIncome,
                            format: currencyFormat,
                            onTapSpent: () =>
                                openFlowSheet('expense', 'Gastos'),
                            onTapIncome: () =>
                                openFlowSheet('income', 'Receita'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _changeMonth(WidgetRef ref, int delta) {
    final current = ref.read(summaryMonthRangeProvider);
    var newFrom = DateTime(current.from.year, current.from.month + delta, 1);
    var newTo =
        DateTime(newFrom.year, newFrom.month + 1, 0); // último dia do mês
    final today = DateTime.now();
    if (newFrom.year == today.year && newFrom.month == today.month) {
      newTo = today;
    }
    if (newFrom.isAfter(today)) return;

    ref.read(summaryMonthRangeProvider.notifier).state = (
      from: newFrom,
      to: newTo,
    );
  }
}

// ============================================================================
// Metric card (saldo, posição, dívida)
// ============================================================================

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BmoColors.screenBgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
  }
}

// ============================================================================
// Fatura em aberto card
// ============================================================================

class _BillCard extends StatelessWidget {
  final BillInfo? bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    if (bill == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BmoColors.screenBgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BmoColors.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: const Text(
          'Fatura em aberto: sem fatura importada',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
      );
    }

    final formattedAmount = currencyFormat.format(bill!.totalAmount);
    String? dueLabel;
    if (bill!.dueDate != null) {
      try {
        final due = DateTime.parse(bill!.dueDate!);
        dueLabel = DateFormat('dd/MM/yyyy').format(due);
      } catch (_) {
        dueLabel = bill!.dueDate;
      }
    }

    String? importedLabel;
    if (bill!.importedAt != null) {
      try {
        final utc = DateTime.parse(bill!.importedAt!);
        final local = utc.toLocal();
        importedLabel =
            'atualizado em ${DateFormat('dd/MM HH:mm').format(local)}';
      } catch (_) {
        importedLabel = 'atualizado em ${bill!.importedAt}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BmoColors.accentYellow.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long,
                  size: 14, color: BmoColors.accentYellow),
              SizedBox(width: 6),
              Text(
                'Fatura em aberto',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formattedAmount,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BmoColors.accentYellow,
            ),
          ),
          if (dueLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'Vencimento $dueLabel',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textSecondary,
              ),
            ),
          ],
          if (bill!.itemCount != null || importedLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (bill!.itemCount != null)
                  '${bill!.itemCount} itens',
                ?importedLabel,
              ].join(' · '),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Compact gastos/receita (replaces old 2 separate cards)
// ============================================================================

class _CompactFlowCard extends StatelessWidget {
  final double spent;
  final double income;
  final NumberFormat format;
  final VoidCallback? onTapSpent;
  final VoidCallback? onTapIncome;

  const _CompactFlowCard({
    required this.spent,
    required this.income,
    required this.format,
    this.onTapSpent,
    this.onTapIncome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do mês',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          _FlowRow(
            label: 'Gastos',
            value: format.format(spent),
            color: BmoColors.accentRed,
            onTap: onTapSpent,
          ),
          const SizedBox(height: 4),
          _FlowRow(
            label: 'Receita',
            value: format.format(income),
            color: BmoColors.accentGreen,
            onTap: onTapIncome,
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _FlowRow({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Month button
// ============================================================================

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MonthButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Icon(icon, size: 18, color: BmoColors.textPrimary),
        ),
      ),
    );
  }
}
