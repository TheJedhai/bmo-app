import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/dedup_review.dart';
import '../../data/models/transaction.dart';

/// Card de revisão de duplicata: transações lado a lado.
class DedupReviewCard extends StatelessWidget {
  final DedupReview review;
  final void Function(String resolution) onResolve;

  const DedupReviewCard({
    super.key,
    required this.review,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    final txA = review.transactionA;
    final txB = review.transactionB;

    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: BmoColors.accentYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'São a mesma compra?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: BmoColors.accentYellow,
              ),
            ),
            const SizedBox(height: 16),
            // Lado a lado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: txA != null
                      ? _TransactionDetail(tx: txA, label: 'Compra A')
                      : const _EmptyDetail(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.compare_arrows,
                      color: BmoColors.textMuted, size: 20),
                ),
                Expanded(
                  child: txB != null
                      ? _TransactionDetail(tx: txB, label: 'Compra B')
                      : const _EmptyDetail(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onResolve('real'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BmoColors.accentGreen,
                      side:
                          const BorderSide(color: BmoColors.accentGreen),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'São compras separadas',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => onResolve('duplicate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BmoColors.accentRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'É duplicata',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BmoColors.screenBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          '—',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _TransactionDetail extends StatelessWidget {
  final Transaction tx;
  final String label;

  const _TransactionDetail({required this.tx, required this.label});

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BmoColors.screenBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BmoColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          _DetailRow(icon: Icons.description, value: tx.description),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.calendar_today,
            value: dateTimeFormat.format(tx.date),
          ),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.attach_money,
            value: currencyFormat.format(tx.amount.abs()),
          ),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.account_balance,
            value: tx.accountId,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _DetailRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: BmoColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
