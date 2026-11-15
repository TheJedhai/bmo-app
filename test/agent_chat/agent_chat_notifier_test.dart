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

  /// Erro lançado pelo `GET /messages` (ex.: 404 de sessão de outro perfil).
  Object? fetchError;

  /// Quantas vezes a lista de sessões foi pedida.
  int listCalls = 0;

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
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
    final error = fetchError;
    if (error != null) throw error;
    if (historyQueue.isEmpty) return const [];
    return historyQueue.removeAt(0);
  }

  @override
  Future<void> cancel(String sessionId) async {
    cancelled.add(sessionId);
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId}) async {
    listCalls++;
    return const [];
  }

  @override
  Future<AgentSession> createSession({String? title, int? projectId}) async =>
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

Iterable<AgentToolPart> _toolsOf(List<AgentMessage> messages, String callId) =>
    messages.expand((m) => m.parts).whereType<AgentToolPart>().where(
          (part) => part.callId == callId,
        );

AgentToolPart? _toolOf(List<AgentMessage> messages, String callId) {
  final tools = _toolsOf(messages, callId);
  return tools.isEmpty ? null : tools.single;
}

/// Forma comparável do estado: papel de cada mensagem e as partes, na ordem.
/// É com isso que o estado ao vivo tem que bater com o `GET .../messages`.
List<String> _signatureOf(List<AgentMessage> messages) => [
      for (final message in messages)
        '${message.role.name}:${message.parts.map(_partSignature).join(' ')}',
    ];

String _partSignature(AgentPart part) => switch (part) {
      AgentTextPart() => 'text',
      AgentReasoningPart() => 'reasoning',
      AgentRichPart() => 'rich',
      AgentToolPart(:final callId, :final status) => 'tool($callId,${status.name})',
      AgentApprovalPart(:final callId, :final decision) =>
        'approval($callId,${decision.name})',
    };

/// Mensagem do assistente no formato de `GET .../messages`.
AgentMessage _historyAssistant(String id, List<Map<String, dynamic>> parts) =>
    AgentMessage.fromJson({'id': id, 'role': 'assistant', 'parts': parts});

Map<String, dynamic> _historyTool(String callId, {required bool ok}) => {
      'type': 'tool',
      'call_id': callId,
      'name': 'delete_task',
      'label': 'Apagar tarefa',
      'ok': ok,
    };

Map<String, dynamic> _historyApproval(
  String callId,
  String decision,
) =>
    {
      'type': 'approval',
      'call_id': callId,
      'tool': 'delete_task',
      'label': 'Apagar tarefa',
      'summary': 'Apagar a tarefa #12',
      'decision': decision,
    };

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
    container.listen(agentConversationProvider(null), (_, _) {});
  });

  AgentConversationState read() => container.read(agentConversationProvider(null));

  AgentConversation notifier() =>
      container.read(agentConversationProvider(null).notifier);

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
    expect(container.read(selectedAgentSessionProvider(null)), 'sess-1');
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

  /// Simula o que o `GET .../messages` devolve depois do turno: recarregar a
  /// sessão tem que produzir a mesma forma do estado ao vivo.
  Future<void> reloadHistory(List<AgentMessage> history) async {
    client.historyQueue = [history];
    container.read(selectedAgentSessionProvider(null).notifier).select(null);
    await pumpEventQueue();
    container.read(selectedAgentSessionProvider(null).notifier).select('sess-1');
    await pumpEventQueue();
  }

  test('aprovação: chip aguardando, rodando e fechado no chip original',
      () async {
    client.onTurn = (sessionId, message, approvals) async* {
      if (approvals == null) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ToolStarted(
          callId: 'call-del',
          name: 'delete_task',
          label: 'Apagar tarefa',
        );
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
      yield const ToolStarted(
        callId: 'call-del',
        name: 'delete_task',
        label: 'Apagar tarefa',
      );
      yield const ToolEnded(callId: 'call-del', ok: true, label: 'Apagar tarefa');
      yield const TextDelta('tarefa apagada');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('apaga');
    await pumpEventQueue();

    // Turno encerrado aguardando decisão: nada de spinner.
    expect(read().status, AgentConversationStatus.idle);
    expect(_toolOf(read().messages, 'call-del')?.status,
        AgentToolStatus.awaiting);
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.pending,
    );

    notifier().approve('call-del');
    // No clique, antes do POST responder.
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.approved,
    );
    expect(_toolOf(read().messages, 'call-del')?.status,
        AgentToolStatus.running);

    await pumpEventQueue();

    final state = read();
    expect(state.status, AgentConversationStatus.idle);
    expect(state.messages.last.plainText, 'tarefa apagada');
    // O tool.start/tool.end da retomada fecharam o chip original.
    expect(_toolOf(state.messages, 'call-del')?.status, AgentToolStatus.ok);
    expect(_toolsOf(state.messages, 'call-del'), hasLength(1));
    expect(client.sentApprovals.last?['call-del']?.approved, isTrue);

    final live = _signatureOf(state.messages);
    await reloadHistory([
      _user('apaga'),
      _historyAssistant('row1:assistant', [
        _historyTool('call-del', ok: true),
        _historyApproval('call-del', 'approved'),
      ]),
      _assistant('tarefa apagada'),
    ]);
    expect(_signatureOf(read().messages), live);
  });

  test('negação: chip negado e sem duplicado', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      if (approvals == null) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ToolStarted(
          callId: 'call-del',
          name: 'delete_task',
          label: 'Apagar tarefa',
        );
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
      yield const ToolEnded(callId: 'call-del', ok: false, label: 'Apagar tarefa');
      yield const TextDelta('não apaguei');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('apaga');
    await pumpEventQueue();
    notifier().deny('call-del', note: 'não');

    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.denied,
    );
    expect(_toolOf(read().messages, 'call-del')?.status,
        AgentToolStatus.denied);

    await pumpEventQueue();

    final state = read();
    expect(state.status, AgentConversationStatus.idle);
    expect(state.messages.last.plainText, 'não apaguei');
    // O tool.end da retomada não transforma a negação em falha.
    expect(_toolOf(state.messages, 'call-del')?.status, AgentToolStatus.denied);
    expect(_toolsOf(state.messages, 'call-del'), hasLength(1));

    final live = _signatureOf(state.messages);
    await reloadHistory([
      _user('apaga'),
      _historyAssistant('row1:assistant', [
        _historyTool('call-del', ok: false),
        _historyApproval('call-del', 'denied'),
      ]),
      _assistant('não apaguei'),
    ]);
    expect(_signatureOf(read().messages), live);
  });

  test('mensagem com pendência: card negado e turno segue', () async {
    var call = 0;
    client.onTurn = (sessionId, message, approvals) async* {
      call++;
      if (call == 1) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ToolStarted(
          callId: 'call-del',
          name: 'delete_task',
          label: 'Apagar tarefa',
        );
        yield const ApprovalRequested(
          callId: 'call-del',
          tool: 'delete_task',
          label: 'Apagar tarefa',
          summary: 'Apagar a tarefa #12',
        );
        yield const TurnEnded(status: 'awaiting_approval');
        return;
      }
      // Turno novo numa sessão com pendência: o servidor nega e segue.
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const ToolEnded(callId: 'call-del', ok: false, label: 'Apagar tarefa');
      yield const TextDelta('seguindo a conversa');
      yield const TurnEnded(status: 'completed');
    };

    notifier().send('apaga');
    await pumpEventQueue();
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.pending,
    );

    notifier().send('deixa pra lá');
    // Otimista, antes do POST.
    expect(
      _approvalOf(read().messages, 'call-del')?.decision,
      AgentApprovalDecision.denied,
    );
    expect(_approvalOf(read().messages, 'call-del')?.ignored, isTrue);
    expect(_toolOf(read().messages, 'call-del')?.status,
        AgentToolStatus.denied);

    await pumpEventQueue();

    final state = read();
    expect(state.status, AgentConversationStatus.idle);
    expect(state.messages.map((m) => m.role), [
      AgentRole.user,
      AgentRole.assistant,
      AgentRole.user,
      AgentRole.assistant,
    ]);
    expect(state.messages[2].plainText, 'deixa pra lá');
    expect(state.messages[3].plainText, 'seguindo a conversa');
    expect(_toolsOf(state.messages, 'call-del'), hasLength(1));
    expect(_toolOf(state.messages, 'call-del')?.status, AgentToolStatus.denied);

    final live = _signatureOf(state.messages);
    await reloadHistory([
      _user('apaga'),
      _historyAssistant('row1:assistant', [
        _historyTool('call-del', ok: false),
        _historyApproval('call-del', 'denied'),
      ]),
      _user('deixa pra lá'),
      _assistant('seguindo a conversa'),
    ]);
    expect(_signatureOf(read().messages), live);
  });

  test('falha no POST de aprovação volta o card para pendente e mostra o erro',
      () async {
    var call = 0;
    client.onTurn = (sessionId, message, approvals) async* {
      call++;
      if (call == 1) {
        yield const TurnStarted(input: 'message', sessionId: 'sess-1');
        yield const ToolStarted(
          callId: 'call-del',
          name: 'delete_task',
          label: 'Apagar tarefa',
        );
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
    expect(_toolOf(state.messages, 'call-del')?.status,
        AgentToolStatus.awaiting);
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

  test('trocar de perfil zera o estado e larga a sessão selecionada', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      yield const TurnStarted(input: 'message', sessionId: 'sess-1');
      yield const TextDelta('oi');
      yield const TurnEnded(status: 'completed');
    };
    notifier().send('oi');
    await pumpEventQueue();
    expect(read().messages, isNotEmpty);
    expect(container.read(selectedAgentSessionProvider(null)), 'sess-1');

    // Jedhai (1) → Convidado (2).
    container.read(currentUserIdProvider.notifier).state = 2;
    await pumpEventQueue();

    expect(read().messages, isEmpty);
    expect(read().sessionId, isNull);
    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    // Nada de buscar a sessão do perfil anterior.
    expect(client.fetchedSessions, isEmpty);

    // Voltar para o perfil antigo não restaura a seleção.
    container.read(currentUserIdProvider.notifier).state = 1;
    await pumpEventQueue();

    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    expect(client.fetchedSessions, isEmpty);
  });

  test('sessão selecionada não vaza ao trocar de perfil', () async {
    client.historyQueue = [
      [_user('antiga'), _assistant('resposta antiga')],
    ];
    container.read(selectedAgentSessionProvider(null).notifier).select('sess-1');
    await pumpEventQueue();
    expect(client.fetchedSessions, ['sess-1']);
    expect(read().messages, hasLength(2));

    container.read(currentUserIdProvider.notifier).state = 2;
    await pumpEventQueue();

    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    expect(read().messages, isEmpty);
    expect(client.fetchedSessions, ['sess-1']);
  });

  test('404 no GET do histórico limpa a seleção, recarrega e avisa',
      () async {
    container.listen(agentSessionsProvider(null), (_, _) {});
    await pumpEventQueue();
    final before = client.listCalls;

    client.fetchError =
        const AgentChatException(404, 'not_found', 'Session sess-1 not found');
    container.read(selectedAgentSessionProvider(null).notifier).select('sess-1');
    await pumpEventQueue();

    final state = read();
    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    expect(state.error, 'essa conversa não existe mais');
    expect(state.messages, isEmpty);
    expect(state.loadingHistory, isFalse);
    expect(client.listCalls, before + 1);
  });

  test('404 no envio limpa a seleção e devolve o texto ao campo', () async {
    container.listen(agentSessionsProvider(null), (_, _) {});
    client.historyQueue = [
      [_user('antiga'), _assistant('resposta antiga')],
    ];
    container.read(selectedAgentSessionProvider(null).notifier).select('sess-1');
    await pumpEventQueue();
    final before = client.listCalls;

    client.onTurn = (sessionId, message, approvals) async* {
      throw const AgentChatException(404, 'not_found', 'Session sess-1 not found');
    };
    notifier().send('que horas são?');
    await pumpEventQueue();

    final state = read();
    expect(container.read(selectedAgentSessionProvider(null)), isNull);
    expect(state.sessionId, isNull);
    expect(state.error, 'essa conversa não existe mais');
    expect(state.restoreDraft, 'que horas são?');
    expect(state.messages, isEmpty);
    expect(state.status, AgentConversationStatus.idle);
    expect(client.listCalls, before + 1);
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

    container.read(selectedAgentSessionProvider(null).notifier).select(null);
    await pumpEventQueue();
    expect(read().messages, isEmpty);
    expect(read().sessionId, isNull);

    client.historyQueue = [
      [_user('primeira'), _assistant('resposta')],
    ];
    container.read(selectedAgentSessionProvider(null).notifier).select('sess-1');
    await pumpEventQueue();

    final state = read();
    expect(client.fetchedSessions, ['sess-1']);
    expect(state.messages, hasLength(2));
    expect(state.messages.map((m) => m.plainText), ['primeira', 'resposta']);
    expect(state.sessionId, 'sess-1');
  });

  test('erro HTTP antes do turno vira mensagem visível', () async {
    client.onTurn = (sessionId, message, approvals) async* {
      throw const AgentChatException(500, 'internal', 'boom');
    };

    notifier().send('oi');
    await pumpEventQueue();

    final state = read();
    expect(state.error, contains('boom'));
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

  // ── o stream só mexe na mensagem do assistente do turno ──────────────────

  List<AgentPart> partsOf(AgentConversationState state, AgentRole role) =>
      state.messages.singleWhere((m) => m.role == role).parts;

  void expectUserOnly(String text) {
    final parts = partsOf(read(), AgentRole.user);
    expect(parts, hasLength(1));
    expect((parts.single as AgentTextPart).text, text);
  }

  test('tool, depois texto: usuário fica intacto no meio do stream', () async {
    final controller = StreamController<AgentEvent>();
    addTearDown(controller.close);
    client.onTurn = (sessionId, message, approvals) => controller.stream;

    notifier().send('que horas são?');
    await pumpEventQueue();

    controller.add(const TurnStarted(input: 'message', sessionId: 'sess-1'));
    controller.add(const ToolStarted(
        callId: 'c1', name: 'clock', label: 'Ver horas'));
    controller.add(const ToolEnded(
        callId: 'c1', ok: true, label: 'Ver horas'));
    controller.add(const TextDelta('São 19h'));
    await _until(
      () => partsOf(read(), AgentRole.assistant).isNotEmpty &&
          partsOf(read(), AgentRole.assistant).last is AgentTextPart &&
          (partsOf(read(), AgentRole.assistant).last as AgentTextPart).text ==
              'São 19h',
      reason: 'primeiro text.delta',
    );

    expectUserOnly('que horas são?');
    final assistant = partsOf(read(), AgentRole.assistant);
    expect(assistant, hasLength(2));
    expect(assistant[0], isA<AgentToolPart>());
    expect((assistant[0] as AgentToolPart).status, AgentToolStatus.ok);
    expect((assistant[1] as AgentTextPart).text, 'São 19h');

    controller.add(const TextDelta('05'));
    await _until(
      () => (partsOf(read(), AgentRole.assistant).last as AgentTextPart).text ==
          'São 19h05',
      reason: 'segundo text.delta',
    );

    expectUserOnly('que horas são?');
    expect(partsOf(read(), AgentRole.assistant), hasLength(2));
  });

  test('só texto: usuário fica intacto a cada delta', () async {
    final controller = StreamController<AgentEvent>();
    addTearDown(controller.close);
    client.onTurn = (sessionId, message, approvals) => controller.stream;

    notifier().send('oi');
    await pumpEventQueue();

    controller.add(const TextDelta('Olá'));
    await _until(() => read().messages.last.plainText == 'Olá',
        reason: 'primeiro delta');
    expectUserOnly('oi');

    controller.add(const TextDelta(', tudo bem?'));
    await _until(() => read().messages.last.plainText == 'Olá, tudo bem?',
        reason: 'segundo delta');

    expectUserOnly('oi');
    final assistant = partsOf(read(), AgentRole.assistant);
    expect(assistant, hasLength(1));
    expect((assistant.single as AgentTextPart).text, 'Olá, tudo bem?');
  });

  test('reasoning antes do texto: usuário fica intacto', () async {
    final controller = StreamController<AgentEvent>();
    addTearDown(controller.close);
    client.onTurn = (sessionId, message, approvals) => controller.stream;

    notifier().send('oi');
    await pumpEventQueue();

    controller.add(const ReasoningDelta('pensando'));
    controller.add(const TextDelta('São 19h'));
    await _until(() => read().messages.last.plainText == 'São 19h',
        reason: 'texto depois do reasoning');

    expectUserOnly('oi');
    final assistant = partsOf(read(), AgentRole.assistant);
    expect(assistant, hasLength(2));
    expect((assistant[0] as AgentReasoningPart).text, 'pensando');
    expect((assistant[1] as AgentTextPart).text, 'São 19h');
  });
}
