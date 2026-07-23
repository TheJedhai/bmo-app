import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/finances_providers.dart';
import 'transaction_list_sheet.dart';

/// Cards do mês (gastos, receita, net) com seletor de mês.
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

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Gastos',
                      value: currencyFormat.format(summary.totalSpent.abs()),
                      color: BmoColors.accentRed,
                      onTap: () =>
                          openFlowSheet('expense', 'Gastos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Receita',
                      value: currencyFormat.format(summary.totalIncome),
                      color: BmoColors.accentGreen,
                      onTap: () =>
                          openFlowSheet('income', 'Receita'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Saldo',
                      value: currencyFormat.format(summary.net),
                      color: summary.net >= 0
                          ? BmoColors.accentGreen
                          : BmoColors.accentRed,
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
    var newTo = DateTime(newFrom.year, newFrom.month + 1, 0); // último dia do mês
    final today = DateTime.now();
    // Se for o mês atual, limita o "to" a hoje
    if (newFrom.year == today.year && newFrom.month == today.month) {
      newTo = today;
    }
    // Não permite navegar para o futuro
    if (newFrom.isAfter(today)) return;

    ref.read(summaryMonthRangeProvider.notifier).state = (
      from: newFrom,
      to: newTo,
    );
  }
}

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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
