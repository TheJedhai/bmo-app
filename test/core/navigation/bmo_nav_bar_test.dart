// Nav bar: item ativo por prefixo (Coding continua marcado em sub-rotas) e
// toque sempre levando à raiz do item.
//
// Run:
//   flutter test test/core/navigation/bmo_nav_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/core/widgets/bmo_nav_bar.dart';
import 'package:bmo_app/features/rss/data/rss_providers.dart';

Widget _page(BuildContext context, String label, String location) {
  return Scaffold(
    body: Stack(
      children: [
        Center(child: Text(label)),
        BmoNavBar(currentLocation: location),
      ],
    ),
  );
}

void main() {
  test('navRouteIsActive casa o item e as sub-rotas', () {
    expect(navRouteIsActive('/coding', '/coding'), isTrue);
    expect(navRouteIsActive('/coding', '/coding/4'), isTrue);
    expect(navRouteIsActive('/coding', '/coding/4/chat'), isTrue);
    expect(navRouteIsActive('/coding', '/coding/runs/42'), isTrue);
    expect(navRouteIsActive('/coding', '/codingx'), isFalse);
    expect(navRouteIsActive('/chat', '/coding/4/chat'), isFalse);
    // Dashboard só casa exata — prefixo '/' marcaria tudo.
    expect(navRouteIsActive('/', '/'), isTrue);
    expect(navRouteIsActive('/', '/coding/4'), isFalse);
  });

  testWidgets('Coding fica ativo em sub-rota e tocar em Chat vai ao principal',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/coding/4/chat',
      routes: [
        GoRoute(
          path: '/coding/:projectId/chat',
          builder: (context, state) =>
              _page(context, 'project chat', state.uri.path),
        ),
        GoRoute(
          path: '/coding',
          builder: (context, state) =>
              _page(context, 'coding root', state.uri.path),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) =>
              _page(context, 'main chat', state.uri.path),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [unreadCountProvider.overrideWith((ref) async => 0)],
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

    Color iconColor(String tooltip) => tester
        .widget<Icon>(
          find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(Icon),
          ),
        )
        .color!;

    expect(find.text('project chat'), findsOneWidget);
    expect(iconColor('Coding'), BmoColors.accentGreen);
    expect(iconColor('Chat'), BmoColors.textMuted);

    // Aba Chat não está selecionada: tocar leva ao chat principal.
    await tester.tap(find.byTooltip('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('main chat'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/chat');
    expect(iconColor('Chat'), BmoColors.accentGreen);
    expect(iconColor('Coding'), BmoColors.textMuted);
  });

  testWidgets('tocar no item ativo em sub-rota volta para a raiz dele',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/coding/4/chat',
      routes: [
        GoRoute(
          path: '/coding/:projectId/chat',
          builder: (context, state) =>
              _page(context, 'project chat', state.uri.path),
        ),
        GoRoute(
          path: '/coding',
          builder: (context, state) =>
              _page(context, 'coding root', state.uri.path),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) =>
              _page(context, 'main chat', state.uri.path),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [unreadCountProvider.overrideWith((ref) async => 0)],
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

    await tester.tap(find.byTooltip('Coding'));
    await tester.pumpAndSettle();

    expect(find.text('coding root'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/coding');
  });
}
