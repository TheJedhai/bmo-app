import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/finances_client.dart';
import '../../data/finances_providers.dart';
import '../../data/models/transaction.dart';

/// Bottom sheet content: lista de transações filtrada por flow/categoria.
///
/// Usada tanto pelo clique em categoria (flow=expense, category=nome)
/// quanto pelos cards de Gastos (flow=expense) e Receita (flow=income).
class TransactionListSheet extends ConsumerStatefulWidget {
  final String title;
  final String? flow;
  final String? category;
  final DateTime from;
  final DateTime to;

  const TransactionListSheet({
    super.key,
    required this.title,
    this.flow,
    this.category,
    required this.from,
    required this.to,
  });

  @override
  ConsumerState<TransactionListSheet> createState() =>
      _TransactionListSheetState();
}

class _TransactionListSheetState extends ConsumerState<TransactionListSheet> {
  List<Transaction>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final client = ref.read(financesClientProvider);
      final (items, _) = await client.listTransactions(
        from: widget.from,
        to: widget.to,
        flow: widget.flow,
        category: widget.category,
        pageSize: 50,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on FinancesApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BmoColors.textMuted.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BmoColors.textPrimary,
                  ),
                ),
              ),
              const Divider(color: BmoColors.screenBgElevated, height: 1),
              // Content
              Expanded(child: _buildContent(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
        ),
      );
    }
    if (_items!.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma transação neste período.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textMuted,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final tx = _items![index];
        final dateStr = DateFormat('dd/MM/yyyy').format(tx.date);
        final isExpense = tx.displayAmount < 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: BmoColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatCurrency(tx.displayAmount),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isExpense
                      ? BmoColors.accentRed.withValues(alpha: 0.8)
                      : BmoColors.accentGreen,
                ),
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

    final buf = StringBuffer();
    final chars = intPart.split('');
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && (chars.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(chars[i]);
    }

    final formatted = 'R\$ ${buf.toString()},$decPart';
    return value < 0 ? '-$formatted' : formatted;
  }
}
