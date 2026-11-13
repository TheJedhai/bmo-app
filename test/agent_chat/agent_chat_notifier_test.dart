// Notifier da conversa v2 com cliente fake — nenhum teste toca a rede.
//
// Run:
//   flutter test test/agent_chat/agent_chat_notifier_test.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';

typedef TurnHandler = Stream<AgentEvent> Function(
  String? sessionId,
  String? message,
  Map<String, AgentApprovalInput>? approvals,
);

class FakeAgentChatClient extends AgentChatClient {
  FakeAgentChatClient() : super(client: http.Client(), baseUrl: 'http://fake');

  TurnHandler? onTurn;

  /// Sessões devolvidas pelo `GET /messages`, na ordem das chamadas.
  List<List<AgentMessage>> historyQueue = [];

  final List<String> fetchedSessions = [];
  final List<String?> sentMessages = [];
  final List<Map<String, AgentApprovalInput>?> sentApprovals = [];
  final List<String> cancelled = [];

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
  }) {
    sentMessages.add(message);
    sentApprovals.add(approvals);
    final handler = onTurn;
    if (handler == null) return const Stream.empty();
    return handler(sessionId, message, approvals);
  }

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    fetchedSessions.add(sessionId);
    if (historyQueue.isEmpty) return const [];
    return historyQueue.removeAt(0);
  }

  @override
  Future<void> cancel(String sessionId) async {
    cancelled.add(sessionId);
  }

  @override
  Future<List<AgentSession>> listSessions() async => const [];

  @override
  Future<AgentSession> createSession({String? title}) async =>
      AgentSession(id: 'created', title: title ?? 'Nova conversa');

  @override
  Future<AgentSession> renameSession(String sessionId, String title) async =>
      AgentSession(id: sessionId, title: title);

  @override
  Future<void> deleteSession(String sessionId) async {}
}

AgentMessage _user(String text) => AgentMessage(
      id: 'u-$text',
      role: AgentRole.user,
      parts: [AgentTextPart(text)],
    );

AgentMessage _assistant(String text) => AgentMessage(
      id: 'a-$text',
      role: AgentRole.assistant,
      parts: [AgentTextPart(text)],
    );


/// Espera até [predicate] ficar verdadeiro (ou falha). Evita corrida entre o
/// gerador async* do fake, os timers do polling e o `pumpEventQueue`.
Future<void> _until(bool Function() predicate, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timeout esperando ${reason ?? "estado"}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

AgentApprovalPart? _approvalOf(List<AgentMessage> messages, String callId) {
  for (final message in messages) {
    for (final part in message.parts) {
      if (part is AgentApprovalPart && part.callId == callId) return part;
    }
  }
  return null;
}

void main() {
  late FakeAgentChatClient client;
  late ProviderContainer container;

  setUp(() {
    client = FakeAgentChatClient();
    container = ProviderContainer(overrides: [
      agentChatClientProvider.overrideWithValue(client),
      agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
    ]);
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;
    // Mantém o provider vivo para reagir às mudanças de dependência.
    container.listen(agentConversationProvider, (_, _) {});
  });

  AgentConversationState read() => container.read(agentConversationProvider);

  AgentConversation notifier() =>
      container.read(agentConversationProvider.notifier);

  test('turno completo acumula texto e adota o session_id do turn.start',
      () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield TurnStarted(input: 'message', sessionId: 'sess-1', turnId: 't');
      yield const TextDelta('Olá, ');
      yield const TextDelta('Jedhai!');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('oi');
    await pumpEventQueue();

    final state = read();
    expect(state.messages, hasLength(2));
    expect(state.messages.first.role, AgentRole.user);
    expect(state.messages.first.plainText, 'oi');
    expect(state.messages.last.plainText, 'Olá, Jedhai!');
    expect(state.status, AgentConversationStatus.idle);
    expect(state.sessionId, 'sess-1');
    expect(container.read(selectedAgentSessionProvider), 'sess-1');
  });

  test('ferramenta abre em rodando e fecha no tool.end', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const ToolStarted(
        callId: 'c1',
        name: 'list_tasks',
        label: 'Listar tarefas',
      );
      yield const ToolEnded(callId: 'c1', ok: true, label: 'Listar tarefas');
      yield const TextDelta('pronto');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('lista');
    await pumpEventQueue();

    final tool = read()
        .messages
        .last
        .parts
        .whereType<AgentToolPart>()
        .singleWhere((part) => part.callId == 'c1');
    expect(tool.label, 'Listar tarefas');
    expect(tool.status, AgentToolStatus.ok);
  });

  test('aprovação: card pendente, decisão otimista e retomada em nova mensagem',
      () async {
    var call = 0;
    client.onTurn = (sessionId, message, approvals) async* {
      call++;
      if (call == 1) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ApprovalRequested(
          callId: 'call-del',
          tool: 'delete_task',
          label: 'Apagar tarefa',
          summary: 'Apagar a tarefa #12',
        );
        yield const TurnEnded(status: 'awaiting_approval');
        return;
      }
      yield const TurnStarted(input: 'approval', sessionId: 'sess-1');
      yield const TextDelta('tarefa apagada');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('apaga');
    await pumpEventQueue();

    expect(read().status, AgentConversationStatus.awaitingApproval);
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.pending,
    );

    final before = read().messages.length;
    notifier().approve('call-del');
    // No clique, antes do POST responder.
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.approved,
    );
    await pumpEventQueue();

    final state = read();
    expect(state.status, AgentConversationStatus.idle);
    expect(state.messages.length, before + 1);
    expect(state.messages.last.plainText, 'tarefa apagada');
    expect(client.sentApprovals.last?['call-del']?.approved, isTrue);
  });

  test('falha no POST de aprovação volta o card para pendente e mostra o erro',
      () async {
    var call = 0;
    client.onTurn = (sessionId, message, approvals) async* {
      call++;
      if (call == 1) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ApprovalRequested(
          callId: 'call-del',
          tool: 'delete_task',
          label: 'Apagar tarefa',
          summary: 'Apagar a tarefa #12',
        );
        yield const TurnEnded(status: 'awaiting_approval');
        return;
      }
      throw const AgentChatException(409, 'turn_in_progress', 'ocupado');
    };

    notifier().send('apaga');
    await pumpEventQueue();
    notifier().deny('call-del', note: 'não');

    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.denied,
    );
    await pumpEventQueue();

    final state = read();
    expect(
      _approvalOf(state.messages, 'call-del')?.decision,
      AgentApprovalDecision.pending,
    );
    expect(state.error, 'já existe um turno rodando nesta conversa');
    expect(state.status, AgentConversationStatus.idle);
  });

  test('stream que morre sem turn.end faz polling até a resposta aparecer',
      () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const TextDelta('escrevendo');
      // Sem turn.end: conexão caiu.
    };
    // Primeira leitura ainda sem a resposta final; a segunda já tem.
    client.historyQueue = [
      [_user('oi'), _assistant('escrevendo')],
      [_user('oi'), _assistant('escrevendo a resposta inteira')],
    ];

    notifier().send('oi');
    // Polling: a resposta só aparece na segunda tentativa.
    await _until(
      () => read().messages.isNotEmpty &&
          read().messages.last.plainText == 'escrevendo a resposta inteira',
      reason: 'refetch com a resposta completa',
    );

    final state = read();
    expect(client.fetchedSessions, ['sess-1', 'sess-1']);
    expect(state.messages.last.plainText, 'escrevendo a resposta inteira');
    expect(state.status, AgentConversationStatus.idle);
    expect(state.refreshFailed, isFalse);
  });

  test('polling sem novidade esgota e marca refreshFailed', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const TextDelta('parcial');
    };
    client.historyQueue = [
      for (var i = 0; i < kAgentChatPollAttempts + 1; i++)
        [_user('oi'), _assistant('parcial')],
    ];

    notifier().send('oi');
    await _until(() => read().refreshFailed, reason: 'refreshFailed');

    final state = read();
    expect(state.refreshFailed, isTrue);
    expect(state.status, AgentConversationStatus.idle);

    // Clique em "tentar de novo" recomeça o ciclo (fila do fake zerada).
    client.fetchedSessions.clear();
    client.historyQueue = [
      [_user('oi'), _assistant('parcial'), _assistant('completa')],
    ];
    notifier().refreshNow();
    await _until(
      () => read().messages.last.plainText == 'completa',
      reason: 'retry concluído',
    );

    expect(read().refreshFailed, isFalse);
    expect(read().messages.last.plainText, 'completa');
  });

  test('trocar de perfil zera o estado', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const TextDelta('oi');
      yield const TurnEnded(status: 'completed');
    };
    notifier().send('oi');
    await pumpEventQueue();
    expect(read().messages, isNotEmpty);

    container.read(currentUserIdProvider.notifier).state = null;
    await pumpEventQueue();

    expect(read().messages, isEmpty);
    expect(read().sessionId, isNull);
  });

  test('Nova zera o estado e voltar pela lista carrega sem duplicar', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const TextDelta('resposta');
      yield const TurnEnded(status: 'completed');
    };
    notifier().send('primeira');
    await pumpEventQueue();
    expect(read().messages, hasLength(2));
    // A migração não pode ter recarregado o histórico.
    expect(client.fetchedSessions, isEmpty);

    container.read(selectedAgentSessionProvider.notifier).state = null;
    await pumpEventQueue();
    expect(read().messages, isEmpty);
    expect(read().sessionId, isNull);

    client.historyQueue = [
      [_user('primeira'), _assistant('resposta')],
    ];
    container.read(selectedAgentSessionProvider.notifier).state = 'sess-1';
    await pumpEventQueue();

    final state = read();
    expect(client.fetchedSessions, ['sess-1']);
    expect(state.messages, hasLength(2));
    expect(state.messages.map((m) => m.plainText), ['primeira', 'resposta']);
    expect(state.sessionId, 'sess-1');
  });

  test('erro HTTP antes do turno vira mensagem visível', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      throw const AgentChatException(404, 'not_found', 'Session x not found');
    };

    notifier().send('oi');
    await pumpEventQueue();

    final state = read();
    expect(state.error, 'sessão não encontrada');
    expect(state.status, AgentConversationStatus.idle);
  });

  test('parar só chama cancel quando o usuário pede', () async {
    final controller = StreamController<AgentEvent>();
    client.onTurn = (sessionId, message, approvals) => controller.stream;

    notifier().send('oi');
    await pumpEventQueue();
    controller.add(const TurnStarted(input: 'message', sessionId: 'sess-1'));
    await pumpEventQueue();

    await notifier().cancel();
    expect(client.cancelled, ['sess-1']);

    controller.add(const TurnEnded(status: 'cancelled'));
    await controller.close();
    await pumpEventQueue();
    expect(read().status, AgentConversationStatus.idle);
  });
}
