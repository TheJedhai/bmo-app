// Navegação da área de Coding: conversa de projeto em `/coding/N/chat`, link
// antigo `/chat?project=N` redirecionado e detalhe da tarefa com rota real.
//
// Usa a tabela de rotas de produção ([appRoutes]) num router enxuto, sem o
// shell/identidade. Providers falsos — nenhum teste toca a rede.
//
// Run:
//   flutter test test/coding/coding_navigation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/navigation/app_router.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_run_providers.dart';
import 'package:bmo_app/features/coding/data/coding_task_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
import 'package:bmo_app/features/coding/data/models/coding_task.dart';

class FakeProjects extends ProjectsNotifier {
  @override
  Future<List<CodingProject>> build() async => const [
        CodingProject(
          id: 4,
          name: 'scratch-run',
          primaryPath: '~/scratch-run',
          extraPaths: [],
          permissionMode: 'default',
          allowRules: [],
          denyRules: [],
          createdAt: '',
          updatedAt: '',
        ),
      ];
}

class FakeSessions extends AgentSessions {
  @override
  Future<List<AgentSession>> build(int? projectId) async => const [
        AgentSession(id: 'sess-1', title: 'conversa do projeto'),
      ];
}

class FakeConversation extends AgentConversation {
  @override
  AgentConversationState build(int? projectId) =>
      const AgentConversationState();
}

class FakeRunEvents extends CodingRunEvents {
  @override
  Future<List<CodingRunEvent>> build(int runId) async => const [];
}

const _run = CodingRun(
  id: 42,
  projectId: 4,
  prompt: 'adiciona testes do card',
  status: CodingRunStatus.success,
);

const _task = CodingTask(
  taskId: 9,
  projectId: 4,
  status: CodingTaskStatus.readyToJoin,
  objective: 'adiciona testes do card',
  currentStep: 1,
  stepsTotal: 2,
);

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      redirect: redirectLegacyProjectChat,
      routes: appRoutes,
    );

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      projectsProvider.overrideWith(FakeProjects.new),
      agentSessionsProvider(4).overrideWith(FakeSessions.new),
      agentConversationProvider(4).overrideWith(FakeConversation.new),
      codingTasksProvider(4).overrideWith(FakeTasks.new),
      codingTaskProvider(9).overrideWith((ref) async => _task),
      codingRunProvider(42).overrideWith((ref) async => _run),
      codingRunEventsProvider(42).overrideWith(FakeRunEvents.new),
    ],
  );
  container.read(enabledFeaturesProvider.notifier).state = {'coding'};
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  GoRouter router,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class FakeTasks extends CodingTasks {
  @override
  Future<List<CodingTask>> build(int projectId) async => [_task];
}

void main() {
  testWidgets('conversa do projeto abre em /coding/4/chat e volta ao projeto',
      (tester) async {
    final router = _router('/coding/4');
    addTearDown(router.dispose);
    final container = _container();
    addTearDown(container.dispose);

    await _pump(tester, router, container);
    expect(find.text('SCRATCH-RUN'), findsOneWidget);

    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();

    // URL do chat de projeto, não do chat principal.
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/coding/4/chat',
    );
    expect(find.text('scratch-run'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/coding/4');
    expect(find.text('SCRATCH-RUN'), findsOneWidget);
  });

  testWidgets('link antigo /chat?project=4 redireciona para /coding/4/chat',
      (tester) async {
    final router = _router('/chat?project=4');
    addTearDown(router.dispose);
    final container = _container();
    addTearDown(container.dispose);

    await _pump(tester, router, container);

    expect(router.routeInformationProvider.value.uri.path, '/coding/4/chat');
    expect(find.text('scratch-run'), findsOneWidget);
  });

  testWidgets('tarefa do projeto abre em /coding/tasks/9', (tester) async {
    final router = _router('/coding/4');
    addTearDown(router.dispose);
    final container = _container();
    addTearDown(container.dispose);

    await _pump(tester, router, container);

    await tester.tap(find.text('adiciona testes do card'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/coding/tasks/9');
    expect(find.text('TAREFA #9'), findsOneWidget);
  });
}
