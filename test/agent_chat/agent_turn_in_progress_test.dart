// POST com 409 `turn_in_progress`: nada de reenvio automático, texto volta
// para o campo, indicador "BMO respondendo" liga e o turn_completed libera.
//
// Run:
//   flutter test test/agent_chat/agent_turn_in_progress_test.dart

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

class BusyAgentChatClient extends AgentChatClient {
  BusyAgentChatClient() : super(client: http.Client(), baseUrl: 'http://fake');

  int sendCalls = 0;
  int fetchCalls = 0;

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {
    sendCalls++;
    throw const AgentChatException(409, 'turn_in_progress',
        'turno em andamento nesta conversa');
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId, String kind = 'chat'}) async => const [];

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    fetchCalls++;
    return const [
      AgentMessage(
        id: 'm1',
        role: AgentRole.assistant,
        parts: [AgentTextPart('resposta do outro cliente')],
      ),
    ];
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
  late BusyAgentChatClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = BusyAgentChatClient();
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
    container
        .read(selectedAgentSessionProvider(null).notifier)
        .select('sess-1');
    container.listen(agentConversationProvider(null), (_, _) {});
  });

  AgentConversationState state() =>
      container.read(agentConversationProvider(null));

  test('409 mostra "BMO respondendo" e devolve o texto, sem reenvio',
      () async {
    await _until(() => state().loadingHistory == false);

    container.read(agentConversationProvider(null).notifier).send('oi');

    await _until(() => state().remoteTurn && !state().isBusy);

    expect(client.sendCalls, 1, reason: 'nada de reenvio automático');
    expect(state().remoteTurn, isTrue);
    expect(state().error, isNull);
    expect(state().restoreDraft, 'oi');
    // A mensagem otimista (e a bolha vazia) saem: o servidor não aceitou o
    // turno. Fica só o que já era histórico.
    expect(state().messages.map((m) => m.id), ['m1']);
    expect(
      state().messages.where((m) => m.role == AgentRole.user),
      isEmpty,
    );
  });

  test('turn_completed limpa o indicador e atualiza a conversa', () async {
    await _until(() => state().loadingHistory == false);
    container.read(agentConversationProvider(null).notifier).send('oi');
    await _until(() => state().remoteTurn);

    final fetchesBefore = client.fetchCalls;
    events.add({
      'type': 'session.turn_completed',
      'session_id': 'sess-1',
      'turn_id': 'other-1',
    });

    await _until(() => !state().remoteTurn && client.fetchCalls > fetchesBefore);
    expect(state().isBusy, isFalse);
    expect(state().messages.single.id, 'm1');
  });

  test('usuário pode mandar de novo depois do turn_completed', () async {
    await _until(() => state().loadingHistory == false);
    container.read(agentConversationProvider(null).notifier).send('oi');
    await _until(() => state().remoteTurn);

    events.add({
      'type': 'session.turn_completed',
      'session_id': 'sess-1',
      'turn_id': 'other-1',
    });
    await _until(() => !state().remoteTurn);

    container.read(agentConversationProvider(null).notifier).send('de novo');
    await _until(() => client.sendCalls == 2);
    expect(client.sendCalls, 2);
  });
}
