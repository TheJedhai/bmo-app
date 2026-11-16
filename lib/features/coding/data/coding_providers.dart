import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import 'coding_client.dart';
import 'models/coding_project.dart';

// ============================================================
// Infra
// ============================================================

final codingClientProvider = Provider<CodingClient>((ref) {
  return CodingClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

// ============================================================
// Projects
// ============================================================

class ProjectsNotifier extends AsyncNotifier<List<CodingProject>> {
  @override
  Future<List<CodingProject>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final client = ref.watch(codingClientProvider);
    return client.listProjects();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final client = ref.read(codingClientProvider);
    state = await AsyncValue.guard(() => client.listProjects());
  }

  Future<CodingProject> createProject(Map<String, dynamic> data) async {
    final client = ref.read(codingClientProvider);
    final project = await client.createProject(data);
    await refresh();
    return project;
  }

  Future<CodingProject> updateProject(int id, Map<String, dynamic> data) async {
    final client = ref.read(codingClientProvider);
    final project = await client.updateProject(id, data);
    await refresh();
    return project;
  }

  /// `coding.plan.updated {project_id, plan}` — plano ativo ao vivo.
  /// `plan: null` limpa (plano cancelado/concluído no servidor).
  void applyPlan(int projectId, Map<String, dynamic>? plan) {
    final current = state.valueOrNull;
    if (current == null) return;
    final parsed = plan == null ? null : CodingPlan.fromJson(plan);
    state = AsyncData([
      for (final project in current)
        if (project.id == projectId) project.copyWithPlan(parsed) else project,
    ]);
  }

  Future<void> deleteProject(int id) async {
    final client = ref.read(codingClientProvider);
    await client.deleteProject(id);
    await refresh();
  }

  Future<CodingProject> syncProject(int id) async {
    final client = ref.read(codingClientProvider);
    final project = await client.syncProject(id);
    await refresh();
    return project;
  }
}

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<CodingProject>>(
  ProjectsNotifier.new,
);
