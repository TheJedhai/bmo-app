// Card rico `coding_task`: status/passos ao vivo, Juntar com confirmação,
// Cancelar e Retomar. Cliente fake — sem rede.
//
// Run:
//   flutter test test/coding/coding_task_card_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_task.dart';
import 'package:bmo_app/features/coding/presentation/widgets/bmo_rich_coding_task_card.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';

const _block = BmoRichBlock(
  v: 2,
  type: 'coding_task',
  blockId: 'coding-task-7',
  payload: {'task_id': 7},
  mutable: true,
);

CodingTask _task({
  CodingTaskStatus status = CodingTaskStatus.running,
  int stepsDone = 1,
  bool canJoin = false,
  String? lastEvent = 'executando o passo 2',
  String? errorMessage,
}) => CodingTask(
  taskId: 7,
  projectId: 1,
  status: status,
  objective: 'conserta o build e roda os testes',
  currentStep: 2,
  stepsTotal: 3,
  stepsDone: stepsDone,
  costUsd: 0.42,
  durationMs: 65000,
  lastEvent: lastEvent,
  errorMessage: errorMessage,
  branch: 'bmo/task-7',
  canJoin: canJoin,
  steps: const [
    CodingTaskStep(
      stepId: 1,
      seq: 1,
      title: 'consertar o build',
      prompt: 'x',
      status: CodingStepStatus.done,
      attempts: 1,
      maxAttempts: 3,
    ),
    CodingTaskStep(
      stepId: 2,
      seq: 2,
      title: 'rodar os testes',
      prompt: 'y',
      status: CodingStepStatus.running,
      attempts: 2,
      maxAttempts: 3,
    ),
    CodingTaskStep(
      stepId: 3,
      seq: 3,
      title: 'atualizar o changelog',
      prompt: 'z',
      status: CodingStepStatus.pending,
    ),
  ],
);

Map<String, dynamic> _patch({
  required String status,
  bool canJoin = false,
  String? errorMessage,
}) => {
  'task_id': 7,
  'project_id': 1,
  'status': status,
  'objective': 'conserta o build e roda os testes',
  'current_step': 3,
  'steps_total': 3,
  'steps_done': 3,
  'cost_usd': 0.87,
  'duration_ms': 120000,
  'last_event': 'pronta',
  'error_message': errorMessage,
  'branch': 'bmo/task-7',
  'can_join': canJoin,
};

class FakeCodingClient extends CodingClient {
  FakeCodingClient()
    : super(client: http.Client(), baseUrl: 'http://fake');

  int getTaskCalls = 0;
  final List<String> calls = [];
  Object? mergeError;
  CodingTask task = _task();

  @override
  Future<CodingTask> getTask(int taskId) async {
    getTaskCalls++;
    return task;
  }

  @override
  Future<CodingTask> mergeTask(int taskId) async {
    final error = mergeError;
    if (error != null) throw error;
    calls.add('merge');
    task = _task(status: CodingTaskStatus.joined);
    return task;
  }

  @override
  Future<CodingTask> cancelTask(int taskId) async {
    calls.add('cancel');
    task = _task(status: CodingTaskStatus.cancelled);
    return task;
  }

  @override
  Future<CodingTask> resumeTask(int taskId) async {
    calls.add('resume');
    task = _task(status: CodingTaskStatus.running);
    return task;
  }
}

void main() {
  late FakeCodingClient client;
  late ProviderContainer container;
  late StreamController<Map<String, dynamic>> events;

  setUp(() {
    client = FakeCodingClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(
      overrides: [
        codingClientProvider.overrideWithValue(client),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
  });

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: BmoRichCodingTaskCard(block: _block)),
      ),
    ),
  );

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('monta pelo REST: status, progresso, passos, custo e último sinal',
      (tester) async {
    await pumpCard(tester);

    expect(find.text('executando'), findsWidgets);
    expect(find.text('conserta o build e roda os testes'), findsOneWidget);
    expect(find.textContaining('passo 2/3'), findsOneWidget);
    expect(find.text('1. consertar o build'), findsOneWidget);
    expect(find.text('2. rodar os testes'), findsOneWidget);
    expect(find.text('3. atualizar o changelog'), findsOneWidget);
    expect(find.text('US\$ 0.42'), findsOneWidget);
    expect(find.text('executando o passo 2'), findsOneWidget);
    expect(find.text('1min 05s'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Juntar'), findsNothing);
    expect(find.text('Retomar'), findsNothing);
    expect(find.text('Detalhes'), findsOneWidget);
    expect(client.getTaskCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('coding.task.updated aplica o patch e pede novo snapshot',
      (tester) async {
    await pumpCard(tester);
    final getsBefore = client.getTaskCalls;

    events.add({
      'type': 'coding.task.updated',
      'patch': _patch(status: 'pronta_para_juntar', canJoin: true),
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('pronta para juntar'), findsOneWidget);
    expect(find.text('Juntar'), findsOneWidget);
    expect(find.textContaining('US\$ 0.87'), findsOneWidget);
    expect(client.getTaskCalls, greaterThan(getsBefore),
        reason: 'passos só vêm do REST');
  });

  testWidgets('Juntar pede confirmação e aplica a resposta do servidor',
      (tester) async {
    client.task = _task(
      status: CodingTaskStatus.readyToJoin,
      stepsDone: 3,
      canJoin: true,
    );
    await pumpCard(tester);

    await tester.tap(find.text('Juntar'));
    await tester.pumpAndSettle();
    expect(find.text('Juntar na base?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Juntar'));
    await tester.pumpAndSettle();

    expect(client.calls, ['merge']);
    expect(find.text('juntada'), findsOneWidget);
    expect(find.text('Juntar'), findsNothing);
  });

  testWidgets('409 do merge aparece no card sem perder o estado', (tester) async {
    client.task = _task(
      status: CodingTaskStatus.readyToJoin,
      stepsDone: 3,
      canJoin: true,
    );
    client.mergeError = const CodingApiException(
      statusCode: 409,
      message: 'checkout sujo',
    );
    await pumpCard(tester);

    await tester.tap(find.text('Juntar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Juntar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('falha ao juntar'), findsOneWidget);
    expect(find.textContaining('checkout sujo'), findsOneWidget);
    expect(find.text('pronta para juntar'), findsOneWidget);
  });

  testWidgets('bloqueada mostra erro e Retomar chama o POST', (tester) async {
    client.task = _task(
      status: CodingTaskStatus.blocked,
      stepsDone: 1,
      errorMessage: 'testes falharam: 3 vermelhos',
      lastEvent: 'passo 2 falhou',
    );
    await pumpCard(tester);

    expect(find.text('bloqueada'), findsOneWidget);
    expect(find.text('testes falharam: 3 vermelhos'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);

    await tester.tap(find.text('Retomar'));
    await tester.pump();
    await tester.pump();

    expect(client.calls, ['resume']);
    expect(find.text('executando'), findsWidgets);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('Cancelar chama o POST e aplica o cancelamento',
      (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(client.calls, ['cancel']);
    expect(find.text('cancelada'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('remontar mostra o estado vivo sem voltar ao antigo',
      (tester) async {
    await pumpCard(tester);

    events.add({
      'type': 'coding.task.updated',
      'patch': _patch(status: 'juntada'),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('juntada'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpCard(tester);

    expect(find.text('juntada'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
  });
}
