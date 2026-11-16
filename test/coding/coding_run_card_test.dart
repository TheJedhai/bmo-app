// Card rico `coding_run`: aplica `rich.update`, re-sincroniza por REST no mount
// e no reconnect do SSE, e chama o kill. Cliente fake — sem rede.
//
// Run:
//   flutter test test/coding/coding_run_card_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
import 'package:bmo_app/features/coding/presentation/widgets/bmo_rich_coding_run_card.dart';

class FakeCodingClient extends CodingClient {
  FakeCodingClient() : super(client: http.Client(), baseUrl: 'http://fake');

  int getRunCalls = 0;
  final List<int> killed = [];
  Object? killError;

  CodingRun run = CodingRun(
    id: 7,
    projectId: 1,
    prompt: 'conserta o build',
    status: CodingRunStatus.running,
    branch: 'fix/build',
    commitSha: 'abcdef1234567890',
    durationMs: 125000,
    costUsd: 0.5,
    costUsdComputed: 1.25,
  );

  @override
  Future<CodingRun> getRun(int runId) async {
    getRunCalls++;
    return run;
  }

  @override
  Future<void> killRun(int runId) async {
    final error = killError;
    if (error != null) throw error;
    killed.add(runId);
  }
}

const _block = BmoRichBlock(
  v: 2,
  type: 'coding_run',
  blockId: 'coding-run-7',
  payload: {'run_id': 7},
  mutable: true,
);

Map<String, dynamic> _update(Map<String, dynamic> patch) => {
      'type': 'rich.update',
      'block_id': 'coding-run-7',
      'patch': patch,
    };

void main() {
  late FakeCodingClient client;
  late ProviderContainer container;
  late StreamController<Map<String, dynamic>> events;

  setUp(() {
    client = FakeCodingClient();
    events = StreamController<Map<String, dynamic>>();
    container = ProviderContainer(
      overrides: [
        codingClientProvider.overrideWithValue(client),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(events.close);
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: BmoRichCodingRunCard(block: _block)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('monta pelo REST, aplica rich.update e re-sincroniza no mount',
      (tester) async {
    await pumpCard(tester);

    expect(find.text('rodando'), findsOneWidget);
    expect(find.text('fix/build'), findsOneWidget);
    expect(find.text('abcdef1'), findsOneWidget);
    expect(find.text('2min 05s'), findsOneWidget);
    expect(find.text('Parar'), findsOneWidget);
    expect(client.getRunCalls, greaterThanOrEqualTo(1));

    events.add(
      _update({
        'run_id': 7,
        'status': 'success',
        'commit_sha': '1234567890abcdef',
        'files_changed_count': 4,
        'cost_usd_computed': 1.25,
        'last_event': 'commit criado',
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('sucesso'), findsOneWidget);
    expect(find.text('1234567'), findsOneWidget);
    expect(find.text('4 arquivo(s)'), findsOneWidget);
    expect(find.text('US\$ 1.25'), findsOneWidget);
    expect(find.text('commit criado'), findsOneWidget);
    // Run terminal: sem botão de parar.
    expect(find.text('Parar'), findsNothing);
  });

  testWidgets('reconexão do SSE re-sincroniza por REST', (tester) async {
    await pumpCard(tester);
    final before = client.getRunCalls;

    container.read(sseGenerationProvider.notifier).state++;
    await tester.pump();
    await tester.pump();

    expect(client.getRunCalls, greaterThan(before));
  });

  testWidgets('Parar chama o kill e o card vira parado', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Parar'));
    await tester.pump();
    await tester.pump();

    expect(client.killed, [7]);
    expect(find.text('parado'), findsOneWidget);
  });

  testWidgets('erro no kill aparece no card', (tester) async {
    client.killError = const CodingApiException(
      statusCode: 500,
      message: 'boom',
    );
    await pumpCard(tester);

    await tester.tap(find.text('Parar'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('falha ao parar'), findsOneWidget);
    expect(client.killed, isEmpty);
  });

  testWidgets('falha mostra o error_message do snapshot REST', (tester) async {
    client.run = CodingRun(
      id: 7,
      projectId: 1,
      prompt: 'conserta o build',
      status: CodingRunStatus.failed,
      errorCode: 'build_failed',
      errorMessage: 'build quebrou na linha 10',
    );
    await pumpCard(tester);

    expect(find.text('falha'), findsOneWidget);
    expect(find.text('build quebrou na linha 10'), findsOneWidget);
  });

  testWidgets('falha mostra o error_message vindo do rich.update',
      (tester) async {
    await pumpCard(tester);

    events.add(
      _update({
        'status': 'failed',
        'error_code': 'build_failed',
        'error_message': 'teste quebrou: esperava 2',
      }),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('falha'), findsOneWidget);
    expect(find.text('teste quebrou: esperava 2'), findsOneWidget);
  });
}
