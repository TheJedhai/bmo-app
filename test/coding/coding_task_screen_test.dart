// Tela da tarefa: objetivo, passos (veredito, erros, tentativas) e ações.
// Providers falsos — nenhum teste toca a rede.
//
// Run:
//   flutter test test/coding/coding_task_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_task_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_task.dart';
import 'package:bmo_app/features/coding/presentation/coding_task_screen.dart';

CodingTask _task({
  CodingTaskStatus status = CodingTaskStatus.readyToJoin,
  bool canJoin = true,
}) => CodingTask(
  taskId: 9,
  projectId: 1,
  status: status,
  objective: 'conserta o build e roda os testes',
  currentStep: 2,
  stepsTotal: 2,
  stepsDone: 2,
  costUsd: 0.42,
  durationMs: 65000,
  branch: 'bmo/task-9',
  baseBranch: 'main',
  model: 'flash',
  effort: 'medium',
  lastEvent: 'pronta para juntar',
  canJoin: canJoin,
  steps: const [
    CodingTaskStep(
      stepId: 5,
      seq: 1,
      title: 'consertar o build',
      prompt: 'Conserte o build quebrado.',
      status: CodingStepStatus.done,
      attempts: 2,
      maxAttempts: 3,
      commitSha: 'abcdef1234567890',
      verdict: 'ok',
      note: 'build verde',
      costUsd: 0.25,
      durationMs: 30000,
    ),
    CodingTaskStep(
      stepId: 6,
      seq: 2,
      title: 'rodar os testes',
      prompt: 'Rode a suíte inteira.',
      status: CodingStepStatus.failed,
      attempts: 3,
      maxAttempts: 3,
      lastError: 'testes falharam: 3 vermelhos',
    ),
  ],
);

class FakeCodingClient extends CodingClient {
  FakeCodingClient(this.task)
    : super(client: http.Client(), baseUrl: 'http://fake');

  CodingTask task;

  @override
  Future<CodingTask> getTask(int taskId) async => task;
}

class FakeStepRuns extends CodingStepRuns {
  @override
  Map<int, Map<String, dynamic>> build(int stepId) => {
    11: {
      'run_id': 11,
      'step_id': stepId,
      'status': 'failed',
      'cost_usd_computed': 0.12,
    },
  };
}

void main() {
  late ProviderContainer container;

  Future<GoRouter> pump(
    WidgetTester tester, {
    required CodingTask task,
  }) async {
    final router = GoRouter(
      initialLocation: '/coding/tasks/9',
      routes: [
        GoRoute(
          path: '/coding/tasks/:taskId',
          builder: (context, state) => CodingTaskScreen(
            taskId: int.parse(state.pathParameters['taskId']!),
          ),
        ),
        GoRoute(
          path: '/coding/runs/:runId',
          builder: (context, state) =>
              Text('run ${state.pathParameters['runId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        codingClientProvider.overrideWithValue(FakeCodingClient(task)),
        eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
        codingStepRunsProvider(5).overrideWith(FakeStepRuns.new),
        codingStepRunsProvider(6).overrideWith(FakeStepRuns.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('mostra objetivo, passos, veredito, erro e tentativas',
      (tester) async {
    await pump(tester, task: _task());

    expect(find.text('TAREFA #9'), findsOneWidget);
    expect(find.text('conserta o build e roda os testes'), findsOneWidget);
    expect(find.textContaining('passo 2/2'), findsOneWidget);
    expect(find.textContaining('US\$ 0.42'), findsOneWidget);
    expect(find.textContaining('flash · medium'), findsOneWidget);

    expect(find.text('PASSOS'), findsOneWidget);
    expect(find.text('1. consertar o build'), findsOneWidget);
    expect(find.text('Conserte o build quebrado.'), findsOneWidget);
    expect(find.text('tentativas 2/3'), findsOneWidget);
    expect(find.text('veredito: ok'), findsOneWidget);
    expect(find.text('build verde'), findsOneWidget);
    expect(find.text('abcdef1'), findsOneWidget);

    expect(find.text('2. rodar os testes'), findsOneWidget);
    expect(find.text('tentativas 3/3'), findsOneWidget);
    expect(find.text('testes falharam: 3 vermelhos'), findsOneWidget);

    // Tentativas vivas abrem o detalhe do run.
    expect(find.text('tentativa #11 · falha'), findsWidgets);
    expect(find.text('US\$ 0.12'), findsWidgets);
  });

  testWidgets('tocar na tentativa abre /coding/runs/11', (tester) async {
    final router = await pump(tester, task: _task());

    await tester.tap(find.text('tentativa #11 · falha').first);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/coding/runs/11');
    expect(find.text('run 11'), findsOneWidget);
  });

  testWidgets('tarefa pronta mostra Juntar', (tester) async {
    await pump(tester, task: _task());

    expect(find.text('Juntar'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Retomar'), findsNothing);
  });

  testWidgets('tarefa bloqueada mostra Retomar e o erro', (tester) async {
    await pump(
      tester,
      task: CodingTask(
        taskId: 9,
        projectId: 1,
        status: CodingTaskStatus.blocked,
        objective: 'conserta o build e roda os testes',
        errorMessage: 'testes falharam: 3 vermelhos',
        steps: _task().steps,
      ),
    );

    expect(find.text('bloqueada'), findsOneWidget);
    expect(find.text('testes falharam: 3 vermelhos'), findsWidgets);
    expect(find.text('Retomar'), findsOneWidget);
    expect(find.text('Juntar'), findsNothing);
  });
}
