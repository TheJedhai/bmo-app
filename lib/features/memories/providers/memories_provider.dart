import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/memories_client.dart';
import '../data/memories_repository.dart';
import '../data/memory_model.dart';

part 'memories_provider.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final memoriesClientProvider = Provider<MemoriesClient>((ref) {
  return MemoriesClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) {
  return MemoriesRepository(ref.watch(memoriesClientProvider));
});

// ============================================================
// Filtro de escopo (compartilhado entre a lista e a busca)
// ============================================================

@riverpod
class MemoriesScopeMode extends _$MemoriesScopeMode {
  @override
  MemoryScope build() => MemoryScope.all;

  void set(MemoryScope scope) => state = scope;
}

// ============================================================
// Memories
// ============================================================

@riverpod
class Memories extends _$Memories {
  @override
  Future<List<Memory>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final scope = ref.watch(memoriesScopeModeProvider);
    final repo = ref.watch(memoriesRepositoryProvider);
    return repo.list(scope: scope);
  }

  Future<void> createMemory(String content, {bool personal = false}) async {
    final repo = ref.read(memoriesRepositoryProvider);
    final memory = await repo.create(content, personal: personal);
    final current = state.valueOrNull ?? const <Memory>[];
    state = AsyncData([memory, ...current]);
  }

  Future<void> updateMemory(
    int id, {
    String? content,
    bool? personal,
  }) async {
    final repo = ref.read(memoriesRepositoryProvider);
    final updated = await repo.update(id, content: content, personal: personal);
    final current = state.valueOrNull ?? const <Memory>[];
    state = AsyncData([
      for (final m in current)
        if (m.id == id) updated else m,
    ]);
  }

  Future<void> deleteMemory(int id) async {
    final repo = ref.read(memoriesRepositoryProvider);
    await repo.delete(id);
    final current = state.valueOrNull ?? const <Memory>[];
    state = AsyncData(current.where((m) => m.id != id).toList());
  }
}

/// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
///
/// É `family` por query: cada termo digitado gera uma instância, e o
/// `autoDispose` (default) descarta as antigas quando o campo muda.
@riverpod
Future<List<Memory>> memorySearch(MemorySearchRef ref, String query) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final scope = ref.watch(memoriesScopeModeProvider);
  final repo = ref.watch(memoriesRepositoryProvider);
  return repo.search(query: q, scope: scope);
}
