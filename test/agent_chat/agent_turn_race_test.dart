// Corrida do turno próprio x SSE: enquanto o POST deste app está em voo, um
// `session.turn_completed` atrasado (de um turno anterior) não pode ser lido
// como turno remoto — era isso que disparava GET /messages + read no mesmo
// segundo da aprovação.
//
// Também cobre 404 de ação (turno não achado ≠ sessão apagada) e
// approval_not_pending.
//
// Run:
//   flutter test test/agent_chat/agent_turn_race_test.dart

import 'dart:async';

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

AgentMessage _pendingApproval({String content = 'apagar tarefa?'}) => AgentMessage(
      id: 'm-assistant',
      role: AgentRole.assistant,
      parts: [
        AgentTextPart(content),
        const AgentApprovalPart(
          callId: 'c1',
          tool: 'delete_task',
          label: 'Apagar tarefa',
          summary: 'Apagar a tarefa #12',
          decision: AgentApprovalDecision.pending,
        ),
      ],
    );

AgentMessage _userMessage() => const AgentMessage(
      id: 'm-user',
      role: AgentRole.user,
      parts: [AgentTextPart('apaga')],
    );

class RaceClient extends AgentChatClient {
  RaceClient() : super(client: http.Client(), baseUrl: 'http://fake');

  /// Stream do POST em voo (o teste decide quando emitir/fechar).
  /// Broadcast: `close()` completa mesmo sem listener (teardown).
  final turn = StreamController<AgentEvent>.broadcast();

  /// Erro a lançar no POST (ex.: 404/409).
  Object? sendError;

  /// Erro a lançar no GET /messages.
  Object? fetchError;
  bool sessionDeleted = false;

  int fetchCalls = 0;
  final List<String> readCalls = [];
  List<AgentMessage> history = [];

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) {
    final error = sendError;
    if (error != null) {
      return Stream<AgentEvent>.error(error);
    }
    return turn.stream;
  }

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    fetchCalls++;
    final error = fetchError;
    if (error != null) throw error;
    return history;
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId, String kind = 'chat'}) async =>
      [const AgentSession(id: 'sess-1', title: 'conversa')];

  @override
  Future<void> markSessionRead(String sessionId) async =>
      readCalls.add(sessionId);

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
  late RaceClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = RaceClient();
    client.history = [_userMessage(), _pendingApproval()];
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(overrides: [
      agentChatClientProvider.overrideWithValue(client),
      agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
      eventsStreamProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(() async {
      container.dispose();
      await events.close();
      await client.turn.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
    container
        .read(selectedAgentSessionProvider(null).notifier)
        .select('sess-1');
    container.listen(agentConversationProvider(null), (_, _) {});
  });

  AgentConversationState state() =>
      container.read(agentConversationProvider(null));

  AgentConversation notifier() =>
      container.read(agentConversationProvider(null).notifier);

  AgentApprovalDecision? decisionOf(String callId) {
    for (final message in state().messages) {
      for (final part in message.parts) {
        if (part is AgentApprovalPart && part.callId == callId) {
          return part.decision;
        }
      }
    }
    return null;
  }

  test('turn_completed atrasado não refaz o fetch com POST próprio em voo',
      () async {
    await _until(() => state().loadingHistory == false);
    final fetchesAfterOpen = client.fetchCalls;
    client.readCalls.clear();

    notifier().approve('c1');
    await _until(() => state().isBusy);
    expect(decisionOf('c1'), AgentApprovalDecision.approved);

    // Evento de um turno anterior chegando com o POST ainda sem `turn.start`.
    events.add({
      'type': 'session.turn_completed',
      'session_id': 'sess-1',
      'turn_id': 't-anterior',
      'unread': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // Causa do incidente: estes dois lados não podem acontecer.
    expect(client.fetchCalls, fetchesAfterOpen,
        reason: 'GET /messages não deveria ser refeito');
    expect(client.readCalls, isEmpty,
        reason: 'POST read não deveria acontecer');
    expect(state().remoteTurn, isFalse);
    expect(decisionOf('c1'), AgentApprovalDecision.approved);
  });

  test('404 numa ação com a sessão viva não apaga a conversa', () async {
    await _until(() => state().loadingHistory == false);
    client.sendError =
        const AgentChatException(404, 'not_found', 'Turn not found');

    notifier().send('de novo');
    await _until(() => !state().isBusy && state().error != null);

    expect(
      container.read(selectedAgentSessionProvider(null)),
      'sess-1',
      reason: 'sessão continua aberta',
    );
    expect(state().error, isNot('essa conversa não existe mais'));
    expect(state().restoreDraft, 'de novo');
  });

  test('404 na ação e no GET da sessão = conversa não existe mais', () async {
    await _until(() => state().loadingHistory == false);
    client.sendError =
        const AgentChatException(404, 'not_found', 'Session not found');
    client.fetchError =
        const AgentChatException(404, 'not_found', 'Session not found');

    notifier().send('oi');
    await _until(() => !state().isBusy);

    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    expect(state().error, 'essa conversa não existe mais');
  });

  test('409 approval_not_pending refaz o fetch sem mostrar erro', () async {
    await _until(() => state().loadingHistory == false);
    client.sendError = const AgentChatException(
      409,
      'approval_not_pending',
      'essa aprovação não está mais pendente',
    );
    final fetchesAfterOpen = client.fetchCalls;

    notifier().approve('c1');
    await _until(() => !state().isBusy);

    expect(client.fetchCalls, greaterThan(fetchesAfterOpen));
    expect(state().error, isNull);
    // A decisão local não volta para "pendente" no refetch.
    expect(decisionOf('c1'), AgentApprovalDecision.approved);
  });
}
