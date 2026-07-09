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
// Memories
// ============================================================

@riverpod
class Memories extends _$Memories {
  @override
  Future<List<Memory>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final repo = ref.watch(memoriesRepositoryProvider);
    return repo.list();
  }

  Future<void> createMemory(String content) async {
    final repo = ref.read(memoriesRepositoryProvider);
    final memory = await repo.create(content);
    final current = state.valueOrNull ?? const <Memory>[];
    state = AsyncData([memory, ...current]);
  }

  Future<void> updateMemory(int id, String content) async {
    final repo = ref.read(memoriesRepositoryProvider);
    final updated = await repo.update(id, content);
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
