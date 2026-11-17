import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/events/events_provider.dart';
import 'coding_providers.dart';
import 'models/coding_run.dart';

part 'coding_run_providers.g.dart';

/// Quantos eventos por página no detalhe do run.
const int kCodingRunEventsPageSize = 200;

/// Último objeto vivo de um run (`coding.run.created/updated {patch}` e o
/// `rich.update` do card), guardado por run id.
///
/// O payload do bloco no histórico é o do momento da criação; um card
/// remontado por scroll/reload precisa do estado mais recente sem esperar o
/// próximo evento. `keepAlive`: sobrevive ao unmount do card.
@Riverpod(keepAlive: true)
class CodingRunLive extends _$CodingRunLive {
  @override
  Map<String, dynamic>? build(int runId) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _applyEvent(event);
    });
    return null;
  }

  void _applyEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'coding.run.created' || type == 'coding.run.updated') {
      final patch = event['patch'];
      if (patch is! Map) return;
      final map = Map<String, dynamic>.from(patch);
      final rawId = map['run_id'] ?? map['id'];
      final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      if (id != runId) return;
      state = map;
      return;
    }
    if (type == 'rich.update' && event['block_id'] == 'coding-run-$runId') {
      final patch = event['patch'];
      if (patch is Map) state = Map<String, dynamic>.from(patch);
    }
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
