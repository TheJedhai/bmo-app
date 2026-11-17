// Reprodução da falha (Etapa 8a): a novidade da lista vivia só em memória
// (`AgentLiveTurns`, autoDispose, sem replay), então turno concluído com o
// chat desmontado — ou depois de um reload — não deixava ponto nenhum.
//
// O contrato novo vem do servidor (`unread` em GET /api/v2/sessions). Estes
// testes descrevem o comportamento esperado e falham enquanto o app só
// conhece o estado em memória.
//
// Run:
//   flutter test test/agent_chat/agent_session_unread_test.dart

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
import 'package:bmo_app/features/agent_chat/widgets/agent_session_list.dart';

AgentSession _session(String id, String title, {bool unread = false}) =>
    AgentSession.fromJson({'id': id, 'title': title, 'unread': unread});

class FakeUnreadClient extends AgentChatClient {
  FakeUnreadClient() : super(client: http.Client(), baseUrl: 'http://fake');

  List<AgentSession> sessions = [
    _session('A', 'conversa A', unread: true),
    _session('B', 'conversa B'),
  ];

  final List<String> readCalls = [];

  @override
  Future<List<AgentSession>> listSessions({
    int? projectId,
    String kind = 'chat',
  }) async =>
      kind == 'daily' ? const [] : sessions.map((s) => s).toList();

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async => const [];

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {}

  @override
  Future<void> markSessionRead(String sessionId) async {
    readCalls.add(sessionId);
    sessions = [
      for (final session in sessions)
        session.id == sessionId ? session.copyWith(unread: false) : session,
    ];
  }

  @override
  Future<void> cancel(String sessionId) async {}
}

Widget _listApp(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BmoTheme.themeData,
        home: const Scaffold(body: AgentSessionList()),
      ),
    );

void main() {
  late FakeUnreadClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = FakeUnreadClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(overrides: [
      agentChatClientProvider.overrideWithValue(client),
      agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
      eventsStreamProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
  });

  testWidgets('ponto vem do servidor (GET /sessions com unread)',
      (tester) async {
    await tester.pumpWidget(_listApp(container));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsOneWidget);
    // A conversa B (sem unread) não tem ponto.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('conversa B'),
          matching: find.byType(Row),
        ).first,
        matching: find.byIcon(Icons.circle),
      ),
      findsNothing,
    );
  });

  testWidgets('evento com o chat desmontado não perde a novidade',
      (tester) async {
    // Usuário em outra tela quando o turno termina: o servidor grava unread.
    events.add({
      'type': 'session.turn_completed',
      'session_id': 'A',
      'turn_id': 'tA',
      'unread': true,
    });
    await tester.pump(const Duration(milliseconds: 20));
    client.sessions = [
      _session('A', 'conversa A', unread: true),
      _session('B', 'conversa B'),
    ];

    await tester.pumpWidget(_listApp(container));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsOneWidget);
  });

  testWidgets('turn_completed ao vivo atualiza a sessão na lista',
      (tester) async {
    client.sessions = [
      _session('A', 'conversa A'),
      _session('B', 'conversa B'),
    ];
    await tester.pumpWidget(_listApp(container));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsNothing);

    // O servidor já gravou unread; a lista tem de refletir sem reload.
    client.sessions = [
      _session('A', 'conversa A', unread: true),
      _session('B', 'conversa B'),
    ];
    events.add({
      'type': 'session.turn_completed',
      'session_id': 'A',
      'turn_id': 'tA',
      'unread': true,
    });
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsOneWidget);
  });

  testWidgets('session.read de outro dispositivo limpa o ponto',
      (tester) async {
    await tester.pumpWidget(_listApp(container));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsOneWidget);

    client.sessions = [
      _session('A', 'conversa A'),
      _session('B', 'conversa B'),
    ];
    events.add({'type': 'session.read', 'session_id': 'A'});
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsNothing);
  });

  testWidgets('abrir a conversa marca como lida e o ponto some',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BmoTheme.themeData,
          home: const AgentChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.circle), findsOneWidget);

    await tester.tap(find.text('conversa A'));
    await tester.pumpAndSettle();

    expect(client.readCalls, ['A']);
    expect(find.byIcon(Icons.circle), findsNothing);
  });

  testWidgets('turno concluído na conversa aberta também marca como lida',
      (tester) async {
    container.read(selectedAgentSessionProvider(null).notifier).select('B');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BmoTheme.themeData,
          home: const AgentChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    client.readCalls.clear();

    events.add({
      'type': 'session.turn_completed',
      'session_id': 'B',
      'turn_id': 'tB',
      'unread': false,
    });
    await tester.pumpAndSettle();

    expect(client.readCalls, ['B']);
  });
}
