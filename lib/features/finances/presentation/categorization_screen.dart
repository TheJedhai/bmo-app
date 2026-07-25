import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/categorization_providers.dart';
import '../data/finances_providers.dart';
import '../data/models/category.dart';
import 'widgets/category_picker_sheet.dart';

/// Tela de categorização de estabelecimentos pendentes.
///
/// Lista ordenada por valor total DESC — decida primeiro o que representa
/// mais dinheiro. Ao tocar num merchant, abre o seletor de categoria.
class CategorizationScreen extends ConsumerStatefulWidget {
  const CategorizationScreen({super.key});

  @override
  ConsumerState<CategorizationScreen> createState() =>
      _CategorizationScreenState();
}

class _CategorizationScreenState extends ConsumerState<CategorizationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uncategorizedProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Categorizar (${state.items.length})',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          _SinceDropdown(
            current: state.since,
            onChanged: (since) {
              ref.read(uncategorizedProvider.notifier).setSince(since);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(UncategorizedState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: BmoColors.textMuted),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.read(uncategorizedProvider.notifier).load(),
                child: const Text('Tentar novamente',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: BmoColors.accentGreen,
                    )),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum estabelecimento pendente.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textMuted,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: BmoColors.accentGreen,
      onRefresh: () => ref.read(uncategorizedProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final m = state.items[index];
          return _MerchantRow(
            merchant: m.merchantNormalized,
            exampleTitle: m.exampleTitle,
            count: m.count,
            totalAmount: m.totalAmount,
            onTap: () => _onMerchantTap(m.merchantNormalized),
          );
        },
      ),
    );
  }

  Future<void> _onMerchantTap(String merchantNormalized) async {
    final category = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CategoryPickerSheet(),
    );

    if (category == null || !mounted) return;

    try {
      final client = ref.read(financesClientProvider);
      final count = await client.categorize(
        merchantNormalized: merchantNormalized,
        categoryId: category.id,
      );

      // Remove da lista local
      ref
          .read(uncategorizedProvider.notifier)
          .removeLocal(merchantNormalized);

      // Feedback discreto
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count lançamentos categorizados como "${category.name}".'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BmoColors.screenBgElevated,
          ),
        );
      }

      // Invalidar providers que dependem de categoria
      ref.invalidate(summaryProvider);
      ref.read(transactionsProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: BmoColors.screenBgElevated,
          ),
        );
      }
    }
  }
}

// ============================================================================
// Merchant row
// ============================================================================

class _MerchantRow extends StatelessWidget {
  final String merchant;
  final String? exampleTitle;
  final int count;
  final double totalAmount;
  final VoidCallback onTap;

  const _MerchantRow({
    required this.merchant,
    required this.exampleTitle,
    required this.count,
    required this.totalAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Card(
        color: BmoColors.screenBgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchant,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: BmoColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (exampleTitle != null &&
                          exampleTitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          exampleTitle!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: BmoColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(totalAmount),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BmoColors.accentRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count lanç.',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

    return 'R\$ ${buf.toString()},$decPart';
  }
}

// ============================================================================
// Period filter dropdown
// ============================================================================

class _SinceDropdown extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _SinceDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textPrimary,
          ),
          dropdownColor: BmoColors.screenBgElevated,
          icon: const Icon(Icons.expand_more,
              size: 18, color: BmoColors.textMuted),
          items: [
            DropdownMenuItem(
              value: defaultSince(),
              child: const Text('60 dias',
                  style: TextStyle(fontFamily: 'Inter')),
            ),
            const DropdownMenuItem(
              value: 'all',
              child:
                  Text('Tudo', style: TextStyle(fontFamily: 'Inter')),
            ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
