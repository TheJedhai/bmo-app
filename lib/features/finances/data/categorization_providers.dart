import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/identity_state.dart';
import 'finances_providers.dart';
import 'models/category.dart';
import 'models/uncategorized_merchant.dart';

// ============================================================
// Categories
// ============================================================

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final client = ref.watch(financesClientProvider);
    return client.listCategories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final client = ref.read(financesClientProvider);
    state = await AsyncValue.guard(() => client.listCategories());
  }

  Future<Category> create({required String name, required String kind}) async {
    final client = ref.read(financesClientProvider);
    final cat = await client.createCategory(name: name, kind: kind);
    await refresh();
    return cat;
  }

  Future<void> updateCategory(int id, {
    String? name,
    String? kind,
    int? displayOrder,
  }) async {
    final client = ref.read(financesClientProvider);
    await client.updateCategory(id, name: name, kind: kind, displayOrder: displayOrder);
    await refresh();
  }

  Future<void> delete(int id) async {
    final client = ref.read(financesClientProvider);
    await client.deleteCategory(id);
    await refresh();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

// ============================================================
// Uncategorized merchants
// ============================================================

/// Período padrão: últimos 60 dias.
String defaultSince() {
  final d = DateTime.now().subtract(const Duration(days: 60));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class UncategorizedState {
  final List<UncategorizedMerchant> items;
  final bool isLoading;
  final String? error;
  final String since;

  const UncategorizedState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    required this.since,
  });

  UncategorizedState copyWith({
    List<UncategorizedMerchant>? items,
    bool? isLoading,
    String? error,
    String? since,
    bool clearError = false,
  }) {
    return UncategorizedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      since: since ?? this.since,
    );
  }
}

class UncategorizedNotifier extends StateNotifier<UncategorizedState> {
  final Ref _ref;

  UncategorizedNotifier(this._ref)
      : super(UncategorizedState(since: defaultSince())) {
    Future.microtask(() => load());
  }

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = _ref.read(currentUserIdProvider);
      if (userId == null) {
        state = state.copyWith(isLoading: false, items: []);
        return;
      }
      final client = _ref.read(financesClientProvider);
      final since = state.since == 'all' ? null : state.since;
      final items = await client.listUncategorized(since: since);
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSince(String since) {
    if (since == state.since) return;
    state = state.copyWith(since: since, items: []);
    load();
  }

  /// Remove um merchant da lista local (após categorizar).
  void removeLocal(String merchantNormalized) {
    state = state.copyWith(
      items: state.items
          .where((m) => m.merchantNormalized != merchantNormalized)
          .toList(),
    );
  }

  /// Força recarga completa.
  Future<void> refresh() async {
    state = state.copyWith(items: []);
    await load();
  }
}

final uncategorizedProvider =
    StateNotifierProvider<UncategorizedNotifier, UncategorizedState>((ref) {
  return UncategorizedNotifier(ref);
});

/// Contagem de merchants pendentes para badge.
final uncategorizedCountProvider = Provider<int>((ref) {
  final state = ref.watch(uncategorizedProvider);
  return state.items.length;
});
