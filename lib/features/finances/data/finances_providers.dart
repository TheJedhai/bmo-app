import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_provider.dart';
import '../../../core/identity/identity_state.dart';
import 'finances_client.dart';
import 'models/account.dart';

import 'models/summary.dart';
import 'models/transaction.dart';

// ============================================================
// Infraestrutura
// ============================================================

final financesClientProvider = Provider<FinancesClient>((ref) {
  return FinancesClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

// ============================================================
// Summary month range (shared state for month picker)
// ============================================================

/// Intervalo de datas para o summary.
typedef MonthRange = ({DateTime from, DateTime to});

/// Mês atual (dia 1 até hoje) — default para o seletor de mês.
MonthRange _currentMonthRange() {
  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, 1);
  return (from: firstDay, to: now);
}

final summaryMonthRangeProvider = StateProvider<MonthRange>((ref) {
  return _currentMonthRange();
});

// ============================================================
// Accounts
// ============================================================

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final client = ref.watch(financesClientProvider);
    return client.listAccounts();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final client = ref.read(financesClientProvider);
    state = await AsyncValue.guard(() => client.listAccounts());
  }
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

// ============================================================
// Summary
// ============================================================

class SummaryNotifier extends AsyncNotifier<FinanceSummary> {
  @override
  Future<FinanceSummary> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const FinanceSummary(
        checkingBalance: 0,
        totalSpent: 0,
        totalIncome: 0,
        net: 0,
        totalCreditDebt: 0,
        netPosition: 0,
        byCategory: [],
        byAccount: [],
      );
    }
    final range = ref.watch(summaryMonthRangeProvider);
    final client = ref.watch(financesClientProvider);
    return client.getSummary(from: range.from, to: range.to);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final range = ref.read(summaryMonthRangeProvider);
    final client = ref.read(financesClientProvider);
    state = await AsyncValue.guard(
        () => client.getSummary(from: range.from, to: range.to));
  }
}

final summaryProvider =
    AsyncNotifierProvider<SummaryNotifier, FinanceSummary>(
  SummaryNotifier.new,
);

// ============================================================
// Transactions (filters + paginated list)
// ============================================================

class TransactionsFilter {
  final DateTime? from;
  final DateTime? to;
  final String? accountId;
  final String? q;

  const TransactionsFilter({this.from, this.to, this.accountId, this.q});

  TransactionsFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? accountId,
    String? q,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearAccountId = false,
    bool clearQ = false,
  }) {
    return TransactionsFilter(
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      q: clearQ ? null : (q ?? this.q),
    );
  }
}

/// Estado paginado da lista de transações.
class TransactionsState {
  final List<Transaction> items;
  final bool hasMore;
  final bool isLoading;
  final String? error;

  const TransactionsState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  TransactionsState copyWith({
    List<Transaction>? items,
    bool? hasMore,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TransactionsState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super(const TransactionsState()) {
    // Initialize filter with current month range
    final range = _ref.read(summaryMonthRangeProvider);
    _filter = TransactionsFilter(from: range.from, to: range.to);
    Future.microtask(() => loadMore());
  }

  static const _kPageSize = 50;

  TransactionsFilter _filter = const TransactionsFilter();
  int _page = 1;

  /// Altera os filtros e recarrega do zero.
  /// Month range is always preserved from summaryMonthRangeProvider.
  void setFilter(TransactionsFilter filter) {
    final range = _ref.read(summaryMonthRangeProvider);
    _filter = TransactionsFilter(
      from: range.from,
      to: range.to,
      accountId: filter.accountId,
      q: filter.q,
    );
    _page = 1;
    state = const TransactionsState();
    loadMore();
  }

  /// Carrega a próxima página e concatena ao estado.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      final client = _ref.read(financesClientProvider);
      final (items, total) = await client.listTransactions(
        from: _filter.from,
        to: _filter.to,
        accountId: _filter.accountId,
        q: _filter.q,
        pageSize: _kPageSize,
        page: _page,
      );

      _page++;
      final allItems = [...state.items, ...items];
      final hasMore = allItems.length < total;
      state = state.copyWith(
        items: allItems,
        hasMore: hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Força recarga completa (reseta e recarrega página 1).
  Future<void> refresh() async {
    _page = 1;
    state = const TransactionsState();
    await loadMore();
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  final notifier = TransactionsNotifier(ref);
  ref.listen(summaryMonthRangeProvider, (_, next) {
    notifier.setFilter(TransactionsFilter(from: next.from, to: next.to));
  });
  return notifier;
});

// ============================================================
// Hidden categories — visual filter for category breakdown
// ============================================================

/// Persisted set of hidden category names. Scoped by current user id.
class HiddenCategoriesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  HiddenCategoriesNotifier(this._ref) : super(const {}) {
    _load();
  }

  void _load() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final userId = _ref.read(currentUserIdProvider);
    if (prefs == null || userId == null) return;
    try {
      final raw = prefs.getStringList('hidden_categories_$userId');
      if (raw != null) state = raw.toSet();
    } catch (e) {
      debugPrint('HiddenCategories load failed: $e');
    }
  }

  void _persist() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final userId = _ref.read(currentUserIdProvider);
    if (prefs == null || userId == null) return;
    try {
      prefs.setStringList('hidden_categories_$userId', state.toList());
    } catch (e) {
      debugPrint('HiddenCategories persist failed: $e');
    }
  }

  void toggle(String category) {
    final updated = Set<String>.from(state);
    if (updated.contains(category)) {
      updated.remove(category);
    } else {
      updated.add(category);
    }
    state = updated;
    _persist();
  }

  void showAll() {
    state = const {};
    _persist();
  }
}

final hiddenCategoriesProvider =
    StateNotifierProvider<HiddenCategoriesNotifier, Set<String>>((ref) {
  final notifier = HiddenCategoriesNotifier(ref);
  ref.listen(currentUserIdProvider, (_, _) => notifier.showAll());
  return notifier;
});


