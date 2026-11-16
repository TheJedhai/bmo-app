// Runs do projeto ao vivo pelos eventos `coding.run.created` e
// `coding.run.updated {patch}` do /api/v1/stream.
//
// Run:
//   flutter test test/coding/coding_runs_live_test.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_run_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';

Map<String, dynamic> _runJson(int id, {String status = 'running'}) => {
      'id': id,
      'project_id': 1,
      'prompt': 'run $id',
      'status': status,
      'branch': 'bmo/run-$id',
      'last_event': 'início',
      'created_at': '2026-11-01T10:00:00Z',
    };

class FakeCodingClient extends CodingClient {
  FakeCodingClient() : super(client: http.Client(), baseUrl: 'http://fake');

  @override
  Future<List<CodingRun>> listRuns({
    int? projectId,
    int limit = 50,
    int offset = 0,
  }) async =>
      [CodingRun.fromJson(_runJson(2)), CodingRun.fromJson(_runJson(1))];
}

void main() {
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(overrides: [
      codingClientProvider.overrideWithValue(FakeCodingClient()),
      eventsStreamProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
    container.listen(codingRunsProvider(1), (_, _) {});
  });

  List<CodingRun> runs() => container.read(codingRunsProvider(1)).valueOrNull!;

  Future<void> settle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (container.read(codingRunsProvider(1)).valueOrNull == null) {
      if (DateTime.now().isAfter(deadline)) fail('timeout');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('coding.run.created entra no topo da lista', () async {
    await settle();
    expect(runs().map((r) => r.id), [2, 1]);

    events.add({'type': 'coding.run.created', 'run': _runJson(3, status: 'queued')});
    await settle();

    expect(runs().map((r) => r.id), [3, 2, 1]);
    expect(runs().first.status, CodingRunStatus.queued);
  });

  test('coding.run.updated aplica o patch sem perder campos', () async {
    await settle();

    events.add({
      'type': 'coding.run.updated',
      'patch': {
        'id': 2,
        'status': 'success',
        'last_event': 'pronto',
        'cost_usd_computed': 0.87,
        'merged_at': '2026-11-02T09:00:00Z',
      },
    });
    await settle();

    final run = runs().firstWhere((r) => r.id == 2);
    expect(run.status, CodingRunStatus.success);
    expect(run.lastEvent, 'pronto');
    expect(run.costUsdComputed, closeTo(0.87, 1e-9));
    expect(run.isMerged, isTrue);
    expect(run.branch, 'bmo/run-2');
  });

  test('evento de outro projeto é ignorado', () async {
    await settle();

    events.add({
      'type': 'coding.run.updated',
      'patch': {'id': 2, 'project_id': 99, 'last_event': 'de outro projeto'},
    });
    await settle();

    expect(runs().firstWhere((r) => r.id == 2).lastEvent, 'início');
  });

  test('outros eventos não mexem na lista', () async {
    await settle();

    events.add({'type': 'rich.update', 'block_id': 'coding-run-2', 'patch': {}});
    await settle();

    expect(runs().map((r) => r.id), [2, 1]);
  });
}
