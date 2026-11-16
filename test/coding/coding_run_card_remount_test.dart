// Card `coding_run` remontado a partir do histórico: o payload do bloco é o
// do momento da criação, então o estado vivo mais recente (guardado por run
// id) tem prioridade — e não há novo GET quando ele existe.
//
// Run:
//   flutter test test/coding/coding_run_card_remount_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
import 'package:bmo_app/features/coding/presentation/widgets/bmo_rich_coding_run_card.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';

const _block = BmoRichBlock(
  v: 2,
  type: 'coding_run',
  blockId: 'coding-run-7',
  payload: {'run_id': 7},
  mutable: true,
);

class FakeCodingClient extends CodingClient {
  FakeCodingClient() : super(client: http.Client(), baseUrl: 'http://fake');

  int getRunCalls = 0;

  @override
  Future<CodingRun> getRun(int runId) async {
    getRunCalls++;
    return CodingRun(
      id: runId,
      projectId: 1,
      prompt: 'conserta o build',
      status: CodingRunStatus.running,
      lastEvent: 'run.cmd',
    );
  }
}

Map<String, dynamic> _patch(String status) => {
      'run_id': 7,
      'project_id': 1,
      'status': status,
      'branch': 'bmo/run-7',
      'commit_sha': null,
      'files_changed_count': 2,
      'cost_usd': null,
      'cost_usd_computed': 1.42,
      'duration_ms': 90000,
      'last_event': 'pronto',
      'merged_at': '2026-11-16T19:02:11Z',
      'parent_run_id': null,
    };

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: BmoRichCodingRunCard(block: _block)),
        ),
      ),
    );

void main() {
  testWidgets('remontar depois do terminal mostra o terminal sem novo evento',
      (tester) async {
    final client = FakeCodingClient();
    final events = StreamController<Map<String, dynamic>>.broadcast();
    final container = ProviderContainer(overrides: [
      codingClientProvider.overrideWithValue(client),
      eventsStreamProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
    });

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump();
    expect(find.text('rodando'), findsOneWidget);
    expect(find.text('run.cmd'), findsOneWidget);

    events.add({
      'type': 'coding.run.updated',
      'patch': _patch('success'),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('sucesso'), findsOneWidget);
    expect(find.text('juntado na base'), findsOneWidget);

    // Desmonta (histórico reconstruído / scroll) e monta de novo.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final getsBeforeRemount = client.getRunCalls;

    await tester.pumpWidget(_app(container));
    await tester.pump();
    await tester.pump();

    expect(find.text('sucesso'), findsOneWidget);
    expect(find.text('juntado na base'), findsOneWidget);
    expect(find.text('rodando'), findsNothing);
    expect(client.getRunCalls, getsBeforeRemount,
        reason: 'estado vivo dispensa GET no remount');
  });
}
