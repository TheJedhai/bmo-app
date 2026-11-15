// Navegação da lista de projetos: tocar num projeto abre a rota
// `/coding/:projectId` de verdade (URL refletida, sobrevive a reload).
//
// Run:
//   flutter test test/coding/coding_screen_navigation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/presentation/coding_screen.dart';

class FakeProjects extends ProjectsNotifier {
  @override
  Future<List<CodingProject>> build() async => const [
        CodingProject(
          id: 1,
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

void main() {
  testWidgets('tocar no projeto navega para /coding/1 e a URL reflete',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/coding',
      routes: [
        GoRoute(
          path: '/coding',
          builder: (context, state) => const CodingScreen(),
        ),
        GoRoute(
          path: '/coding/:projectId',
          builder: (context, state) =>
              Text('projeto ${state.pathParameters['projectId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [projectsProvider.overrideWith(FakeProjects.new)],
    );
    addTearDown(container.dispose);
    container.read(enabledFeaturesProvider.notifier).state = {'coding'};

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('scratch-run'));
    await tester.pumpAndSettle();

    expect(find.text('projeto 1'), findsOneWidget);
    // `push` não reflete na URL do go_router: continuaria /coding e recarregar
    // perderia o projeto. A navegação usa `go`.
    expect(router.routeInformationProvider.value.uri.toString(), '/coding/1');
    // Nada empilhado: o botão voltar cai no `go('/coding')` do header.
    expect(router.canPop(), isFalse);
  });
}
