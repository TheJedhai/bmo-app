// Tela do projeto de coding: conversas do chat v2 do projeto + tarefas.
// Providers falsos — nenhum teste toca a rede.
//
// Run:
//   flutter test test/coding/coding_project_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_task_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/data/models/coding_task.dart';
import 'package:bmo_app/features/coding/presentation/coding_project_screen.dart';

class FakeAgentSessions extends AgentSessions {
  @override
  Future<List<AgentSession>> build(int? projectId) async => const [
        AgentSession(id: 'sess-1', title: 'conversa do projeto'),
      ];
}

class FakeProjects extends ProjectsNotifier {
  @override
  Future<List<CodingProject>> build() async => const [
        CodingProject(
          id: 1,
          name: 'bmo-app',
          primaryPath: '~/Documents/bmo-app',
          extraPaths: [],
          permissionMode: 'default',
          allowRules: [],
          denyRules: [],
          createdAt: '',
          updatedAt: '',
        ),
      ];
}

final _task = CodingTask(
  taskId: 9,
  projectId: 1,
  status: CodingTaskStatus.readyToJoin,
  objective: 'adiciona testes do card',
  currentStep: 2,
  stepsTotal: 2,
  stepsDone: 2,
  costUsd: 0.42,
  lastEvent: 'revisão aprovou o passo 2',
  canJoin: true,
);

class FakeTasks extends CodingTasks {
  @override
  Future<List<CodingTask>> build(int projectId) async => [_task];
}

void main() {
  testWidgets('mostra conversas e tarefas do projeto e abre a conversa',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/coding/1',
      routes: [
        GoRoute(
          path: '/coding/:projectId',
          builder: (context, state) => CodingProjectScreen(
            projectId: int.parse(state.pathParameters['projectId']!),
          ),
        ),
        GoRoute(
          path: '/coding/:projectId/chat',
          builder: (context, state) => Scaffold(
            body: Text(
              'chat do projeto ${state.pathParameters['projectId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        agentSessionsProvider(1).overrideWith(FakeAgentSessions.new),
        codingTasksProvider(1).overrideWith(FakeTasks.new),
        projectsProvider.overrideWith(FakeProjects.new),
        eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;
    // Gate opt-in da feature.
    container.read(enabledFeaturesProvider.notifier).state = {'coding'};

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BMO-APP'), findsOneWidget);
    expect(find.text('conversa do projeto'), findsOneWidget);
    expect(find.text('adiciona testes do card'), findsOneWidget);
    expect(find.text('revisão aprovou o passo 2'), findsOneWidget);
    // status, passo, quando e custo na linha da tarefa
    expect(find.textContaining('pronta para juntar'), findsOneWidget);
    expect(find.textContaining('passo 2/2'), findsOneWidget);
    expect(find.textContaining('US\$ 0.42'), findsOneWidget);

    // "Nova" (ou tocar numa conversa) abre o chat v2 com o projectId.
    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();
    expect(find.text('chat do projeto 1'), findsOneWidget);
  });

  testWidgets('tocar na tarefa abre /coding/tasks/9', (tester) async {
    final router = GoRouter(
      initialLocation: '/coding/1',
      routes: [
        GoRoute(
          path: '/coding/:projectId',
          builder: (context, state) => CodingProjectScreen(
            projectId: int.parse(state.pathParameters['projectId']!),
          ),
        ),
        GoRoute(
          path: '/coding/tasks/:taskId',
          builder: (context, state) => Scaffold(
            body: Text('tarefa ${state.pathParameters['taskId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        agentSessionsProvider(1).overrideWith(FakeAgentSessions.new),
        codingTasksProvider(1).overrideWith(FakeTasks.new),
        projectsProvider.overrideWith(FakeProjects.new),
        eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(enabledFeaturesProvider.notifier).state = {'coding'};

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('adiciona testes do card'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/coding/tasks/9');
    expect(find.text('tarefa 9'), findsOneWidget);
  });
}
