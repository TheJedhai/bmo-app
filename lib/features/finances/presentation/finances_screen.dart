import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';

import '../data/categorization_providers.dart';
import '../data/finances_providers.dart';
import '../data/models/summary.dart';
import 'categorization_screen.dart';
import 'widgets/accounts_header.dart';

import 'widgets/summary_section.dart';
import 'widgets/transaction_list_sheet.dart';
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
      ),
      body: RefreshIndicator(
        color: BmoColors.accentGreen,
        onRefresh: () async {
          await Future.wait([
            ref.read(accountsProvider.notifier).refresh(),
            ref.read(summaryProvider.notifier).refresh(),
            ref.read(transactionsProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ---- Contas ----
            const SliverToBoxAdapter(child: AccountsHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ---- Categorizar (pendências) ----
            const SliverToBoxAdapter(child: _CategorizeCard()),
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
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
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
// Category breakdown (collapsible)
// ============================================================================

/// Cores categóricas com boa separação visual entre fatias vizinhas.
const _pieColors = [
  Color(0xFF8FB8E8), // azul
  Color(0xFFE8938A), // coral
  Color(0xFF8BE0B8), // verde
  Color(0xFFE8D8A0), // dourado
  Color(0xFFC89DE0), // roxo
  Color(0xFFE8B87A), // laranja
  Color(0xFF6AD8C8), // teal
  Color(0xFFE8A0C8), // rosa
  Color(0xFFA0C8E8), // azul claro
  Color(0xFFD0C0A0), // bege
];

/// Limiar para agrupar categorias pequenas como "Outros" no gráfico.
const _kMinSlicePercent = 0.04;

class _CategoryBreakdown extends ConsumerStatefulWidget {
  const _CategoryBreakdown();

  @override
  ConsumerState<_CategoryBreakdown> createState() =>
      _CategoryBreakdownState();
}

class _CategoryBreakdownState extends ConsumerState<_CategoryBreakdown> {
  bool _listExpanded = true;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(summaryProvider);
    final range = ref.watch(summaryMonthRangeProvider);

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

        final total =
            unique.fold<double>(0, (sum, c) => sum + c.total.abs());
        if (total == 0) return const SizedBox.shrink();

        // Hidden categories — visual filter
        final hidden = ref.watch(hiddenCategoriesProvider);
        final visible =
            unique.where((c) => !hidden.contains(c.category)).toList();
        final visibleTotal =
            visible.fold<double>(0, (sum, c) => sum + c.total.abs());
        final displayTotal = visibleTotal > 0 ? visibleTotal : total;

        // Assign consistent colors from full list — colors stay same
        // regardless of hide/show state
        final catColors = <String, Color>{};
        for (var i = 0; i < unique.length; i++) {
          catColors[unique[i].category] =
              _pieColors[i % _pieColors.length];
        }

        void openCategorySheet(CategorySummary cat) {
          final displayName = cat.category;
          final totalFormatted = _formatCurrency(cat.total);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => TransactionListSheet(
              title: '$displayName  •  $totalFormatted',
              flow: 'expense',
              category: cat.category,
              categoryId: cat.categoryId,
              from: range.from,
              to: range.to,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: BmoColors.screenBgElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Por categoria',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: BmoColors.textPrimary,
                            ),
                          ),
                        ),
                        if (hidden.isNotEmpty)
                          GestureDetector(
                            onTap: () => ref
                                .read(hiddenCategoriesProvider.notifier)
                                .showAll(),
                            child: Text(
                              'Mostrar todas',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: BmoColors.accentGreen
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Indicator when categories are hidden
                  if (hidden.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Total considerado: ${_formatCurrency(-visibleTotal.abs())}  ·  '
                      '${hidden.length} categoria${hidden.length > 1 ? 's' : ''} oculta${hidden.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: BmoColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Pie chart — visible categories only
                  _CategoryPie(
                      categories: visible,
                      total: displayTotal,
                      catColors: catColors),
                  const SizedBox(height: 8),
                  // List header — tappable, controls list collapse
                  InkWell(
                    onTap: () =>
                        setState(() => _listExpanded = !_listExpanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          const Text(
                            'Detalhes',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BmoColors.textSecondary,
                            ),
                          ),
                          Icon(
                            _listExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 18,
                            color: BmoColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // List body — collapsible
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _listExpanded
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: unique.map((cat) {
                              final isHidden =
                                  hidden.contains(cat.category);
                              final pct = cat.total.abs() /
                                  (isHidden ? total : displayTotal);
                              return _CategoryListRow(
                                key: ValueKey(
                                    'cat-${cat.category}'),
                                color: catColors[cat.category]!,
                                label: cat.category,
                                value: cat.total,
                                percentage: pct,
                                isHidden: isHidden,
                                onTap: () =>
                                    openCategorySheet(cat),
                                onToggleVisibility: () => ref
                                    .read(hiddenCategoriesProvider
                                        .notifier)
                                    .toggle(cat.category),
                              );
                            }).toList(),
                          )
                        : const SizedBox(
                            width: double.infinity,
                            height: 0,
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

// ============================================================================
// Pie chart (fl_chart)
// ============================================================================

class _CategoryPie extends StatefulWidget {
  final List<CategorySummary> categories;
  final double total;
  final Map<String, Color> catColors;

  const _CategoryPie({
    required this.categories,
    required this.total,
    required this.catColors,
  });

  @override
  State<_CategoryPie> createState() => _CategoryPieState();
}

class _CategoryPieState extends State<_CategoryPie> {
  int _touchedIndex = -1;

  // Metadados de cada fatia para tooltip: label, value, color.
  final _sliceMeta = <({String label, double value, Color color, double pct})>[];

  @override
  Widget build(BuildContext context) {
    _sliceMeta.clear();

    double outrosValue = 0;
    int outrosCount = 0;

    for (final cat in widget.categories) {
      final pct = cat.total.abs() / widget.total;
      if (pct < _kMinSlicePercent) {
        outrosValue += cat.total.abs();
        outrosCount++;
      } else {
        _sliceMeta.add((
          label: cat.category,
          value: cat.total.abs(),
          color: widget.catColors[cat.category]!,
          pct: pct,
        ));
      }
    }

    if (outrosCount > 0) {
      _sliceMeta.add((
        label: 'Outros',
        value: outrosValue,
        color: BmoColors.textMuted,
        pct: outrosValue / widget.total,
      ));
    }

    // If grouping left only 1 slice, undo grouping
    if (_sliceMeta.length <= 1 && outrosCount > 0) {
      _sliceMeta.clear();
      for (final cat in widget.categories) {
        _sliceMeta.add((
          label: cat.category,
          value: cat.total.abs(),
          color: widget.catColors[cat.category]!,
          pct: cat.total.abs() / widget.total,
        ));
      }
    }

    final showTooltip =
        _touchedIndex >= 0 && _touchedIndex < _sliceMeta.length;
    final tooltipMeta = showTooltip ? _sliceMeta[_touchedIndex] : null;

    // Fixed tooltip area — same height always, no layout shift.
    const double tooltipAreaHeight = 42;
    const double pieDiameter = 280.0;
    const double pieRadius = pieDiameter / 2;

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < _sliceMeta.length; i++) {
      final meta = _sliceMeta[i];
      final isTouched = i == _touchedIndex;
      Color color = meta.color;
      if (isTouched) {
        final hsl = HSLColor.fromColor(meta.color);
        final lit = (hsl.lightness + 0.08).clamp(0.0, 1.0);
        color = hsl.withLightness(lit).toColor();
      }
      sections.add(PieChartSectionData(
        color: color,
        value: meta.value,
        title: '',
        radius: pieRadius,
        titleStyle: const TextStyle(fontSize: 0),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: tooltipAreaHeight,
          child: tooltipMeta != null
              ? Align(
                  alignment: Alignment.topCenter,
                  child: _PieTooltip(
                    label: tooltipMeta.label,
                    value: tooltipMeta.value,
                    pct: tooltipMeta.pct,
                    color: tooltipMeta.color,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: pieDiameter,
            height: pieDiameter,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 0,
                sectionsSpace: 0,
                borderData: FlBorderData(show: false),
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      setState(() => _touchedIndex = -1);
                      return;
                    }
                    setState(() => _touchedIndex =
                        response.touchedSection!.touchedSectionIndex);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

}

/// Tooltip flutuante: nome da categoria, valor e porcentagem.
class _PieTooltip extends StatelessWidget {
  final String label;
  final double value;
  final double pct;
  final Color color;

  const _PieTooltip({
    required this.label,
    required this.value,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = _formatCurrency(-value.abs());
    final pctText = '${(pct * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BmoColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatted,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BmoColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            pctText,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Category list row (colored dot + name + value + percentage)
// ============================================================================

class _CategoryListRow extends StatelessWidget {
  final Color color;
  final String label;
  final double value;
  final double percentage;
  final VoidCallback? onTap;
  final bool isHidden;
  final VoidCallback? onToggleVisibility;

  const _CategoryListRow({
    super.key,
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
    this.onTap,
    this.isHidden = false,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = _formatCurrency(value);
    final pctText = '${(percentage * 100).toStringAsFixed(0)}%';

    final effectiveColor = isHidden
        ? BmoColors.textMuted.withValues(alpha: 0.4)
        : color;
    final textColor = isHidden ? BmoColors.textMuted : BmoColors.textPrimary;
    final valueColor = isHidden
        ? BmoColors.textMuted
        : (value < 0
            ? BmoColors.accentRed.withValues(alpha: 0.8)
            : BmoColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatted,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    decoration:
                        isHidden ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHidden
                        ? BmoColors.textMuted.withValues(alpha: 0.08)
                        : BmoColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    pctText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: isHidden
                          ? BmoColors.textMuted.withValues(alpha: 0.5)
                          : BmoColors.textMuted,
                      decoration:
                          isHidden ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggleVisibility,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isHidden ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                      color: isHidden
                          ? BmoColors.textMuted.withValues(alpha: 0.4)
                          : BmoColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
// Categorize card — visível apenas quando há pendências
// ============================================================================

class _CategorizeCard extends ConsumerWidget {
  const _CategorizeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(uncategorizedCountProvider);

    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: BmoColors.screenBgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: BmoColors.accentYellow.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategorizationScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: BmoColors.accentYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.category_outlined,
                    color: BmoColors.accentYellow,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Categorizar ($count)',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: BmoColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
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
