import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/category_labels.dart';
import '../../data/finances_providers.dart';

/// Lista de transações com scroll infinito.
class TransactionsList extends ConsumerWidget {
  const TransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionsProvider.notifier);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    if (state.items.isEmpty && state.isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.items.isEmpty && !state.hasMore) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Nenhuma transação encontrada.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          // Trigger load more
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.loadMore();
          });
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final tx = state.items[index];
        final formattedAmount = _formatTxAmount(tx, currencyFormat);
        final isPositive = tx.isDisplayPositive;
        final catLabel = categoryDisplayName(tx.category);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Card(
            color: BmoColors.screenBgElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Conteúdo principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx.description,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: BmoColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tx.isPending) ...[
                              const SizedBox(width: 6),
                              _PendingBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              catLabel,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: BmoColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateFormat.format(tx.date),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: BmoColors.textMuted,
                              ),
                            ),
                            if (tx.creditCardMetadata != null &&
                                tx.creditCardMetadata!.isInstallment) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: BmoColors.accentYellow
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tx.creditCardMetadata!.label,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: BmoColors.accentYellow,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Valor
                  Text(
                    formattedAmount,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isPositive
                          ? BmoColors.accentGreen
                          : BmoColors.accentRed.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PendingBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: BmoColors.accentYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Pendente',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BmoColors.accentYellow,
        ),
      ),
    );
  }
}

String _formatTxAmount(
    dynamic tx, NumberFormat currencyFormat) {
  final displayAmount = tx.displayAmount as double;
  if (displayAmount >= 0) {
    return currencyFormat.format(displayAmount);
  }
  return '-${currencyFormat.format(displayAmount.abs())}';
}
