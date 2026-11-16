// Memórias não são mais rota: `/memorias` volta para a raiz e a tabela de
// rotas não tem a entrada.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/navigation/app_router.dart';

void main() {
  test('rota /memorias não existe mais', () {
    final paths = <String>[];
    for (final route in appRoutes) {
      if (route is GoRoute) paths.add(route.path);
    }
    expect(paths, isNot(contains('/memorias')));
  });

  testWidgets('link antigo /memorias cai na raiz', (tester) async {
    final router = GoRouter(
      initialLocation: '/memorias',
      redirect: redirectLegacyMemories,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('dashboard'),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
  });
}
