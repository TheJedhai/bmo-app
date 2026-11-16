// Navegação da área de Coding: conversa de projeto em `/coding/N/chat`, link
// antigo `/chat?project=N` redirecionado e detalhe do run com rota real.
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
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';

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
      codingRunsProvider(4).overrideWith(FakeRuns.new),
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

class FakeRuns extends CodingRuns {
  @override
  Future<List<CodingRun>> build(int projectId) async => [_run];
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

  testWidgets('run do projeto abre em /coding/runs/42', (tester) async {
    final router = _router('/coding/4');
    addTearDown(router.dispose);
    final container = _container();
    addTearDown(container.dispose);

    await _pump(tester, router, container);

    await tester.tap(find.text('adiciona testes do card'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/coding/runs/42');
    expect(find.text('RUN #42'), findsOneWidget);
  });
}
