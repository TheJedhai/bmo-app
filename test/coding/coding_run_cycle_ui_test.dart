// UI do ciclo de projeto: custo real (cost_usd_computed), last_event,
// "juntado na base" e link do run pai — card rico e detalhe.
//
// Run:
//   flutter test test/coding/coding_run_cycle_ui_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_run_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
import 'package:bmo_app/features/coding/presentation/coding_run_screen.dart';
import 'package:bmo_app/features/coding/presentation/widgets/bmo_rich_coding_run_card.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';

const _block = BmoRichBlock(
  v: 2,
  type: 'coding_run',
  blockId: 'coding-run-7',
  payload: {'run_id': 7},
  mutable: true,
);

const _usage = {
  'deepseek-v4-pro': {
    'inputTokens': 1782,
    'outputTokens': 1075,
    'cacheReadInputTokens': 1920,
    'cacheCreationInputTokens': 100,
  },
  'deepseek-v4-flash': {
    'inputTokens': 18,
    'outputTokens': 25,
    'cacheReadInputTokens': 0,
    'cacheCreationInputTokens': 0,
  },
};

CodingRun _run({
  CodingRunStatus status = CodingRunStatus.success,
  double? computed = 1.25,
  double? estimated,
  String? lastEvent = 'rodando os testes',
  DateTime? mergedAt,
  int? parentRunId,
  Map<String, dynamic>? usage,
}) =>
    CodingRun(
      id: 7,
      projectId: 1,
      prompt: 'conserta o build',
      status: status,
      branch: 'bmo/run-7',
      lastEvent: lastEvent,
      costUsdComputed: computed,
      costUsd: estimated,
      mergedAt: mergedAt,
      parentRunId: parentRunId,
      usage: usage,
    );

class FakeCodingClient extends CodingClient {
  FakeCodingClient(this.run)
      : super(client: http.Client(), baseUrl: 'http://fake');

  final CodingRun run;

  @override
  Future<CodingRun> getRun(int runId) async => run;

  @override
  Future<List<CodingRun>> listRuns({
    int? projectId,
    int limit = 50,
    int offset = 0,
  }) async =>
      [run];

  @override
  Future<List<CodingRunEvent>> listRunEvents(
    int runId, {
    int afterSeq = 0,
    int limit = 200,
  }) async =>
      const [];
}

Widget _wrap(Widget child, {required CodingRun run}) => ProviderScope(
      overrides: [
        // Gate opt-in da feature (tela do projeto redireciona sem ele).
        enabledFeaturesProvider.overrideWith((ref) => {'coding'}),
        codingClientProvider.overrideWithValue(FakeCodingClient(run)),
        codingRunProvider(run.id).overrideWith((ref) async => run),
        codingRunEventsProvider(run.id).overrideWith(FakeEvents.new),
        eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

class FakeEvents extends CodingRunEvents {
  @override
  Future<List<CodingRunEvent>> build(int runId) async => const [];
}

/// Sem `pumpAndSettle`: run ativo gira spinner infinito.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('card rico', () {
    testWidgets('mostra custo real e último sinal', (tester) async {
      await tester.pumpWidget(_wrap(
        const BmoRichCodingRunCard(block: _block),
        run: _run(),
      ));
      await _settle(tester);

      expect(find.text('US\$ 1.25'), findsOneWidget);
      expect(find.text('rodando os testes'), findsOneWidget);
      expect(find.text('juntado na base'), findsNothing);
    });

    testWidgets('custo não configurado quando cost_usd_computed é null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const BmoRichCodingRunCard(block: _block),
        run: _run(computed: null, estimated: 0.4),
      ));
      await _settle(tester);

      expect(find.text('custo não configurado'), findsOneWidget);
      // Estimativa do Claude Code não aparece no card.
      expect(find.text('US\$ 0.40'), findsNothing);
    });

    testWidgets('mostra juntado na base e link do run pai', (tester) async {
      await tester.pumpWidget(_wrap(
        const BmoRichCodingRunCard(block: _block),
        run: _run(mergedAt: DateTime(2026, 11, 2), parentRunId: 5),
      ));
      await _settle(tester);

      expect(find.text('juntado na base'), findsOneWidget);
      expect(find.text('run pai #5'), findsOneWidget);
    });

    testWidgets('patch de rich.update aplica custo e merge', (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      addTearDown(events.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          codingClientProvider.overrideWithValue(FakeCodingClient(_run())),
          eventsStreamProvider.overrideWith((ref) => events.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BmoRichCodingRunCard(block: _block)),
        ),
      ));
      await _settle(tester);

      events.add({
        'type': 'rich.update',
        'block_id': 'coding-run-7',
        'patch': {
          'status': 'success',
          'cost_usd_computed': 2.5,
          'merged_at': '2026-11-02T09:00:00Z',
          'last_event': 'pronto',
        },
      });
      await _settle(tester);

      expect(find.text('US\$ 2.50'), findsOneWidget);
      expect(find.text('juntado na base'), findsOneWidget);
      expect(find.text('pronto'), findsOneWidget);
      expect(find.text('US\$ 1.25'), findsNothing);
    });
  });

  group('detalhe do run', () {
    testWidgets('custo real, estimativa rotulada e último sinal',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const CodingRunScreen(runId: 7),
        run: _run(estimated: 0.4),
      ));
      await _settle(tester);

      expect(find.text('US\$ 1.25'), findsOneWidget);
      expect(find.text('estimativa Claude Code'), findsOneWidget);
      expect(find.text('US\$ 0.40'), findsOneWidget);
      expect(find.text('último sinal'), findsOneWidget);
      expect(find.text('rodando os testes'), findsOneWidget);
    });

    testWidgets('custo não configurado quando null', (tester) async {
      await tester.pumpWidget(_wrap(
        const CodingRunScreen(runId: 7),
        run: _run(computed: null),
      ));
      await _settle(tester);

      expect(find.text('custo não configurado'), findsOneWidget);
      expect(find.text('estimativa Claude Code'), findsNothing);
    });
  });

  group('usage por modelo', () {
    testWidgets('detalhe mostra entrada, cache, saída e total', (tester) async {
      await tester.pumpWidget(_wrap(
        const CodingRunScreen(runId: 7),
        run: _run(usage: _usage),
      ));
      await _settle(tester);

      expect(
        find.text('deepseek-v4-pro · entrada 1.782 · cache 2.020 · saída 1.075'),
        findsOneWidget,
      );
      expect(
        find.text('deepseek-v4-flash · entrada 18 · cache 0 · saída 25'),
        findsOneWidget,
      );
      expect(
        find.text('total · entrada 1.800 · cache 2.020 · saída 1.100'),
        findsOneWidget,
      );
    });

    testWidgets('usage plano (snake_case) cai numa linha só', (tester) async {
      await tester.pumpWidget(_wrap(
        const CodingRunScreen(runId: 7),
        run: _run(usage: const {
          'input_tokens': 10,
          'output_tokens': 5,
          'cache_read_input_tokens': 2,
          'cache_creation_input_tokens': 1,
        }),
      ));
      await _settle(tester);

      expect(
        find.text('total · entrada 10 · cache 3 · saída 5'),
        findsOneWidget,
      );
    });
  });
}
