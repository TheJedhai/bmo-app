// Conversa do dia (etapa 9): seção "Dias" separada das conversas normais e
// abertura padrão na conversa do dia mais recente.
//
// Run:
//   flutter test test/agent_chat/agent_daily_sessions_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_chat_screen.dart';

class FakeDailyClient extends AgentChatClient {
  FakeDailyClient() : super(client: http.Client(), baseUrl: 'http://fake');

  final daily = [
    AgentSession.fromJson({
      'id': 'D2',
      'title': '18/11/2026',
      'kind': 'daily',
      'day': '2026-11-18',
      'unread': true,
    }),
    AgentSession.fromJson({
      'id': 'D1',
      'title': '17/11/2026',
      'kind': 'daily',
      'day': '2026-11-17',
    }),
  ];

  final readCalls = <String>[];
  final listedKinds = <String>[];
  int? lastProjectId;

  @override
  Future<List<AgentSession>> listSessions({
    int? projectId,
    String kind = 'chat',
  }) async {
    listedKinds.add(kind);
    lastProjectId = projectId;
    if (kind == 'daily') return daily;
    return [
      AgentSession.fromJson({'id': 'C1', 'title': 'conversa normal'}),
    ];
  }

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async => const [];

  @override
  Future<void> markSessionRead(String sessionId) async {
    readCalls.add(sessionId);
  }

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {}

  @override
  Future<void> cancel(String sessionId) async {}
}

Widget _screen(ProviderContainer container, {int? projectId}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BmoTheme.themeData,
        home: AgentChatScreen(projectId: projectId),
      ),
    );

void main() {
  late FakeDailyClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = FakeDailyClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(
      overrides: [
        agentChatClientProvider.overrideWithValue(client),
        agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
  });

  testWidgets('chat principal abre na conversa do dia mais recente', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(container));
    await tester.pumpAndSettle();

    expect(client.listedKinds, contains('daily'));
    expect(
      container.read(selectedAgentSessionProvider(null)),
      'D2',
      reason: 'a data mais recente vem primeiro',
    );
    expect(client.readCalls, contains('D2'));
  });

  testWidgets('seção Dias lista as datas antes das conversas normais', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(container));
    await tester.pumpAndSettle();

    expect(find.text('Dias'), findsOneWidget);
    expect(find.text('Conversas'), findsOneWidget);
    expect(find.text('18/11/2026'), findsOneWidget);
    expect(find.text('17/11/2026'), findsOneWidget);
    expect(find.text('conversa normal'), findsOneWidget);

    final daysY = tester.getTopLeft(find.text('Dias')).dy;
    final normalY = tester.getTopLeft(find.text('conversa normal')).dy;
    expect(daysY, lessThan(normalY));
  });

  testWidgets('chat de projeto não abre conversa do dia', (tester) async {
    await tester.pumpWidget(_screen(container, projectId: 7));
    await tester.pumpAndSettle();

    expect(client.lastProjectId, 7);
    expect(client.listedKinds, isNot(contains('daily')));
    expect(container.read(selectedAgentSessionProvider(7)), isNull);
    expect(find.text('Dias'), findsNothing);
  });
}
