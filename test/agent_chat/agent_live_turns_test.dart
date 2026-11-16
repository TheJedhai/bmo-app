// Eventos SSE targeted de turno (`session.turn_started` / `turn_completed`):
// "BMO respondendo" na conversa aberta, refetch no fim, ponto de novidade na
// lista de conversas.
//
// Run:
//   flutter test test/agent_chat/agent_live_turns_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_live_turns.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_session_list.dart';

class FakeAgentChatClient extends AgentChatClient {
  FakeAgentChatClient() : super(client: http.Client(), baseUrl: 'http://fake');

  List<AgentMessage> messages = const [
    AgentMessage(id: 'm1', role: AgentRole.user, parts: [AgentTextPart('oi')]),
  ];
  int fetchCalls = 0;

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {
    yield const TurnStarted(input: 'message', sessionId: 'sess-1', turnId: 'own-1');
    yield const TurnEnded(status: 'completed');
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId}) async => [
        const AgentSession(id: 'sess-1', title: 'conversa aberta'),
        const AgentSession(id: 'sess-2', title: 'conversa fechada'),
      ];

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    fetchCalls++;
    return messages;
  }

  @override
  Future<void> cancel(String sessionId) async {}
}

Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) fail('timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late FakeAgentChatClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = FakeAgentChatClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(
      overrides: [
        agentChatClientProvider.overrideWithValue(client),
        agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    container.read(currentUserIdProvider.notifier).state = 1;
    container
        .read(selectedAgentSessionProvider(null).notifier)
        .select('sess-1');
    // Mantém o autoDispose vivo e observa o estado.
    container.listen(agentConversationProvider(null), (_, _) {});
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
  });

  AgentConversationState state() =>
      container.read(agentConversationProvider(null));

  void emit(String type, {required String sessionId, required String turnId}) {
    events.add({
      'type': type,
      'session_id': sessionId,
      'turn_id': turnId,
    });
  }

  test('turno de outro cliente mostra "BMO respondendo" e some no fim',
      () async {
    await _until(() => state().loadingHistory == false);
    final fetchesBefore = client.fetchCalls;

    emit('session.turn_started', sessionId: 'sess-1', turnId: 'other-1');
    await _until(() => state().remoteTurn);

    expect(state().remoteTurn, isTrue);
    expect(state().isBusy, isFalse);

    emit('session.turn_completed', sessionId: 'sess-1', turnId: 'other-1');
    await _until(() => !state().remoteTurn);

    // turn_completed refaz o fetch das mensagens.
    await _until(() => client.fetchCalls > fetchesBefore);
    expect(state().remoteTurn, isFalse);
  });

  test('eventos do próprio turno são ignorados', () async {
    await _until(() => state().loadingHistory == false);

    container.read(agentConversationProvider(null).notifier).send('oi');
    await _until(() => !state().isBusy);

    final fetchesAfterTurn = client.fetchCalls;
    emit('session.turn_started', sessionId: 'sess-1', turnId: 'own-1');
    emit('session.turn_completed', sessionId: 'sess-1', turnId: 'own-1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(state().remoteTurn, isFalse);
    expect(client.fetchCalls, fetchesAfterTurn);
  });

  test('turn_completed de outra sessão não mexe nesta conversa', () async {
    await _until(() => state().loadingHistory == false);
    final fetchesBefore = client.fetchCalls;

    emit('session.turn_started', sessionId: 'sess-2', turnId: 'other-2');
    emit('session.turn_completed', sessionId: 'sess-2', turnId: 'other-2');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(state().remoteTurn, isFalse);
    expect(client.fetchCalls, fetchesBefore);
    expect(
      container.read(agentLiveTurnsProvider).hasNovelty('sess-2'),
      isTrue,
    );
  });

  testWidgets('lista marca novidade e some ao abrir a conversa',
      (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: AgentSessionList()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsNothing);

    emit('session.turn_completed', sessionId: 'sess-2', turnId: 'other-2');
    await tester.pumpAndSettle();

    // Um ponto, na conversa que não está aberta.
    expect(find.byIcon(Icons.circle), findsOneWidget);

    await tester.tap(find.text('conversa fechada'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.circle), findsNothing);
    expect(container.read(selectedAgentSessionProvider(null)), 'sess-2');
  });
}
