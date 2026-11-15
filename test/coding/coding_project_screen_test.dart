// Tela do projeto de coding: conversas do chat v2 do projeto + histórico de
// runs. Providers falsos — nenhum teste toca a rede.
//
// Run:
//   flutter test test/coding/coding_project_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_run_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
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

final _run = CodingRun(
  id: 42,
  projectId: 1,
  prompt: 'adiciona testes do card',
  status: CodingRunStatus.success,
  filesChanged: const ['lib/a.dart', 'lib/b.dart'],
  costUsd: 0.42,
  durationMs: 65000,
);

void main() {
  testWidgets('mostra conversas e runs do projeto e abre a conversa',
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
        codingRunsProvider(1).overrideWith((ref) async => [_run]),
        projectsProvider.overrideWith(FakeProjects.new),
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
    // status, quando, duração e custo na linha do run
    expect(
      find.textContaining('sucesso'),
      findsOneWidget,
    );
    expect(find.textContaining('1min 05s'), findsOneWidget);
    expect(find.textContaining('US\$ 0.42'), findsOneWidget);

    // "Nova" (ou tocar numa conversa) abre o chat v2 com o projectId.
    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();
    expect(find.text('chat do projeto 1'), findsOneWidget);
  });
}
