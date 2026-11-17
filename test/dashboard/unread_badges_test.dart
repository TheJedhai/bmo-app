// Badges de não lidos do `unread: {chat, coding}` do /api/v1/me: nav bar
// (Chat e Coding) e cards Chat/Coding da dashboard.
//
// Run:
//   flutter test test/dashboard/unread_badges_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/identity/identity_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/core/widgets/bmo_nav_bar.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/presentation/widgets/coding_dash_card.dart';
import 'package:bmo_app/features/dashboard/widgets/chat_card.dart';
import 'package:bmo_app/features/rss/data/rss_providers.dart';

class FakeSessions extends AgentSessions {
  @override
  Future<List<AgentSession>> build(int? projectId) async => [
        const AgentSession(id: 's1', title: 'conversa um'),
      ];
}

class FakeProjects extends ProjectsNotifier {
  @override
  Future<List<CodingProject>> build() async => const [
        CodingProject(
          id: 1,
          name: 'BMO-APP',
          primaryPath: '/tmp/bmo-app',
          extraPaths: [],
          permissionMode: 'default',
          allowRules: [],
          denyRules: [],
          createdAt: '2026-11-01T00:00:00Z',
          updatedAt: '2026-11-01T00:00:00Z',
        ),
      ];
}

Widget _app(
  Widget child, {
  required int chat,
  required int coding,
  int daily = 0,
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 1),
      enabledFeaturesProvider.overrideWith((ref) => {'coding'}),
      unreadCountProvider.overrideWith((ref) async => 0),
      unreadBadgesProvider.overrideWith(
        (ref) async => UnreadCounts(chat: chat, daily: daily, coding: coding),
      ),
      agentSessionsProvider(null).overrideWith(FakeSessions.new),
      projectsProvider.overrideWith(FakeProjects.new),
    ],
    child: MaterialApp(
      theme: BmoTheme.themeData,
      home: Scaffold(body: Stack(children: [child])),
    ),
  );
}

void main() {
  testWidgets('nav bar mostra os contadores de Chat e Coding', (tester) async {
    await tester.pumpWidget(
      _app(const BmoNavBar(currentLocation: '/chat'), chat: 2, coding: 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('badge do Chat soma conversas normais e conversas do dia',
      (tester) async {
    await tester.pumpWidget(
      _app(const BmoNavBar(currentLocation: '/chat'), chat: 2, daily: 3, coding: 0),
    );
    await tester.pumpAndSettle();

    // 2 + 3: o badge do Chat cobre as duas.
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('nav bar sem não lidos não mostra badge', (tester) async {
    await tester.pumpWidget(
      _app(const BmoNavBar(currentLocation: '/chat'), chat: 0, coding: 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
  });

  testWidgets('card Chat mostra o contador de chat', (tester) async {
    await tester.pumpWidget(
      _app(const ChatCard(accent: BmoColors.accentGreen), chat: 3, coding: 9),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(UnreadBadge, '3'), findsOneWidget);
    expect(find.text('conversa um'), findsOneWidget);
  });

  testWidgets('card Coding mostra o contador de coding', (tester) async {
    await tester.pumpWidget(
      _app(const CodingDashCard(accent: BmoColors.accentBlue), chat: 9, coding: 4),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(UnreadBadge, '4'), findsOneWidget);
  });
}
