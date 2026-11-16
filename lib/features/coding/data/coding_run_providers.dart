import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/events/events_provider.dart';
import '../../../core/identity/identity_state.dart';
import 'coding_providers.dart';
import 'models/coding_run.dart';

part 'coding_run_providers.g.dart';

/// Quantos eventos por página no detalhe do run.
const int kCodingRunEventsPageSize = 200;

/// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
/// devolve), mantido ao vivo pelos eventos `coding.run.*` do
/// `/api/v1/stream`.
@riverpod
class CodingRuns extends _$CodingRuns {
  @override
  Future<List<CodingRun>> build(int projectId) async {
    final userId = ref.watch(currentUserIdProvider);

    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _applyLive(event);
    });

    if (userId == null) return const [];
    final client = ref.watch(codingClientProvider);
    return client.listRuns(projectId: projectId);
  }

  void _applyLive(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'coding.run.created' && type != 'coding.run.updated') return;

    final current = state.valueOrNull;
    if (current == null) return;

    if (type == 'coding.run.created') {
      final json = event['run'] is Map
          ? Map<String, dynamic>.from(event['run'] as Map)
          : event;
      final run = CodingRun.fromJson(json);
      if (run.id <= 0 || run.projectId != projectId) return;
      state = AsyncData([
        run,
        for (final existing in current)
          if (existing.id != run.id) existing,
      ]);
      return;
    }

    final patch = event['patch'];
    if (patch is! Map) return;
    final patchMap = Map<String, dynamic>.from(patch);
    final runId = patchMap['id'] ?? event['run_id'];
    final id = runId is num ? runId.toInt() : int.tryParse('$runId');
    if (id == null) return;

    final patchProject = patchMap['project_id'];
    if (patchProject != null &&
        (patchProject is num ? patchProject.toInt() : 0) != projectId) {
      return;
    }

    var changed = false;
    final next = <CodingRun>[];
    for (final run in current) {
      if (run.id == id) {
        changed = true;
        next.add(run.mergePatch(patchMap));
      } else {
        next.add(run);
      }
    }
    if (changed) state = AsyncData(next);
  }
}

/// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
/// rico no mount e no reconnect do SSE.
@riverpod
Future<CodingRun> codingRun(CodingRunRef ref, int runId) async {
  final client = ref.watch(codingClientProvider);
  return client.getRun(runId);
}

/// Eventos do run, paginados por `after_seq`.
@riverpod
class CodingRunEvents extends _$CodingRunEvents {
  int _runId = 0;
  int _afterSeq = 0;
  bool _hasMore = false;

  /// Ainda há página seguinte (a última veio cheia).
  bool get hasMore => _hasMore;

  @override
  Future<List<CodingRunEvent>> build(int runId) async {
    _runId = runId;
    _afterSeq = 0;
    _hasMore = false;
    final page = await ref
        .watch(codingClientProvider)
        .listRunEvents(runId, afterSeq: 0, limit: kCodingRunEventsPageSize);
    _afterSeq = page.isEmpty ? 0 : page.last.seq;
    _hasMore = page.length == kCodingRunEventsPageSize;
    return page;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !_hasMore) return;
    final page = await ref
        .read(codingClientProvider)
        .listRunEvents(
          _runId,
          afterSeq: _afterSeq,
          limit: kCodingRunEventsPageSize,
        );
    if (page.isEmpty) {
      _hasMore = false;
      return;
    }
    _afterSeq = page.last.seq;
    _hasMore = page.length == kCodingRunEventsPageSize;
    state = AsyncData([...current, ...page]);
  }
}
