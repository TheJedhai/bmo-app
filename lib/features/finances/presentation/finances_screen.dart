import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/category_labels.dart';
import '../data/finances_providers.dart';
import '../data/models/summary.dart';
import 'widgets/accounts_header.dart';
import 'widgets/dedup_review_card.dart';
import 'widgets/summary_section.dart';
import 'widgets/transactions_list.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(dedupPendingCountProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Finanças',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          if (pendingCount > 0)
            Stack(
              children: [
                IconButton(
                  onPressed: () => _scrollToDedup(),
                  icon: const Icon(Icons.compare_arrows,
                      color: BmoColors.accentYellow),
                  tooltip: 'Revisão de duplicatas',
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: BmoColors.accentRed,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      pendingCount.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: BmoColors.accentGreen,
        onRefresh: () async {
          await Future.wait([
            ref.read(accountsProvider.notifier).refresh(),
            ref.read(summaryProvider.notifier).refresh(),
            ref.read(transactionsProvider.notifier).refresh(),
            ref.read(dedupReviewsProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ---- Contas ----
            const SliverToBoxAdapter(child: AccountsHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ---- Resumo mensal ----
            const SliverToBoxAdapter(child: SummarySection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ---- Por categoria ----
            const SliverToBoxAdapter(child: _CategoryBreakdown()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ---- Por conta (rodapé) ----
            const SliverToBoxAdapter(child: _AccountBreakdown()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ---- Extrato ----
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Extrato',
                trailing: _TransactionFilters(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const TransactionsList(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ---- Revisão de duplicatas ----
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Revisão de duplicatas')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: _DedupSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  void _scrollToDedup() {
    // Scroll to bottom where dedup section is.
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }
}

// ============================================================================
// Section header
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: BmoColors.textPrimary,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Category breakdown
// ============================================================================

class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.byCategory.isEmpty) return const SizedBox.shrink();

        final sorted = List<CategorySummary>.from(summary.byCategory)
          ..sort((a, b) => b.total.abs().compareTo(a.total.abs()));

        // Dedup by category name (ponytail: O(n) scan, fine for < 50 categories)
        final seen = <String>{};
        final unique =
            sorted.where((c) => seen.add(c.category)).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: BmoColors.screenBgElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por categoria',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...unique.map((cat) => _CategoryRow(
                        key: ValueKey('cat-${cat.category}'),
                        cat: cat,
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategorySummary cat;

  const _CategoryRow({super.key, required this.cat});

  @override
  Widget build(BuildContext context) {
    final label = categoryDisplayName(cat.category);
    final formatted = _formatCurrency(cat.total);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatted,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cat.total < 0
                  ? BmoColors.accentRed.withValues(alpha: 0.8)
                  : BmoColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: BmoColors.textMuted.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cat.count.toString(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Account breakdown (rodapé)
// ============================================================================

class _AccountBreakdown extends ConsumerWidget {
  const _AccountBreakdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider);

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.byAccount.isEmpty) return const SizedBox.shrink();

        // Dedup by account name
        final seenAccounts = <String>{};
        final uniqueAccounts = summary.byAccount
            .where((a) => seenAccounts.add(a.accountName))
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: BmoColors.screenBgElevated,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Por conta',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...uniqueAccounts.map((acct) => Padding(
                        key: ValueKey('acct-${acct.accountName}'),
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                acct.accountName,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: BmoColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              _formatCurrency(acct.total),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: acct.total < 0
                                    ? BmoColors.accentRed.withValues(alpha: 0.8)
                                    : BmoColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Dedup section
// ============================================================================

class _DedupSection extends ConsumerWidget {
  const _DedupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(dedupReviewsProvider);

    return reviewsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Erro: $error',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
        ),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Text(
                'Nenhuma duplicata pendente.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textMuted,
                ),
              ),
            ),
          );
        }

        return Column(
          children: reviews
              .map((review) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: DedupReviewCard(
                      review: review,
                      onResolve: (resolution) {
                        ref
                            .read(dedupReviewsProvider.notifier)
                            .resolve(review.id, verdict: resolution);
                        // Refetch summary after resolve
                        ref.invalidate(summaryProvider);
                      },
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ============================================================================
// Transaction filters (inline)
// ============================================================================

class _TransactionFilters extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TransactionFilters> createState() =>
      _TransactionFiltersState();
}

class _TransactionFiltersState extends ConsumerState<_TransactionFilters> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 32,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar...',
              hintStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              filled: true,
              fillColor: BmoColors.screenBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              ref.read(transactionsProvider.notifier).setFilter(
                    TransactionsFilter(q: value),
                  );
            },
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.search, size: 18, color: BmoColors.textMuted),
          onPressed: () {
            ref.read(transactionsProvider.notifier).setFilter(
                  TransactionsFilter(q: _searchController.text),
                );
          },
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ============================================================================
// Helpers
// ============================================================================

String _formatCurrency(double value) {
  final absValue = value.abs();
  final formatted = 'R\$ ${_formatNumber(absValue)}';
  return value < 0 ? '-$formatted' : formatted;
}

String _formatNumber(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final integerPart = parts[0];
  final decimalPart = parts[1];

  final buffer = StringBuffer();
  final chars = integerPart.split('');
  for (var i = 0; i < chars.length; i++) {
    if (i > 0 && (chars.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(chars[i]);
  }

  return '${buffer.toString()},$decimalPart';
}
