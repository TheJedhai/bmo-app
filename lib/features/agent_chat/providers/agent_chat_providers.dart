import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/agent_chat_client.dart';
import '../data/agent_event.dart';
import '../data/agent_message.dart';
import '../data/agent_session.dart';
import 'agent_live_turns.dart';

part 'agent_chat_providers.g.dart';

/// Quantas tentativas de polling depois de perder o stream (3 s × 20 = 60 s).
const int kAgentChatPollAttempts = 20;

@riverpod
AgentChatClient agentChatClient(AgentChatClientRef ref) {
  return AgentChatClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
}

/// Intervalo de re-tentativa do `GET .../messages` quando o stream morre.
/// Os testes sobrescrevem com [Duration.zero].
@riverpod
Duration agentChatPollInterval(AgentChatPollIntervalRef ref) =>
    const Duration(seconds: 3);

/// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
/// `session_id: null`).
///
/// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
/// Cada projeto tem a sua própria seleção.
///
/// Depende da identidade de propósito: quando o usuário atual muda, o build
/// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
/// para outro.
///
/// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
/// dashboard, deep link), então não pode morrer por falta de listener.
@Riverpod(keepAlive: true)
class SelectedAgentSession extends _$SelectedAgentSession {
  @override
  String? build(int? projectId) {
    ref.watch(currentUserIdProvider);
    return null;
  }

  void select(String? sessionId) => state = sessionId;
}

// ============================================================
// Lista de sessões
// ============================================================

@riverpod
class AgentSessions extends _$AgentSessions {
  @override
  Future<List<AgentSession>> build(int? projectId) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final client = ref.watch(agentChatClientProvider);
    final sessions = await client.listSessions(projectId: projectId);
    sessions.sort((a, b) {
      final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
      final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
      return right.compareTo(left);
    });
    return sessions;
  }

  Future<void> rename(String sessionId, String title) async {
    final client = ref.read(agentChatClientProvider);
    final renamed = await client.renameSession(sessionId, title);
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData([
      for (final session in current)
        if (session.id == sessionId) renamed else session,
    ]);
  }

  Future<void> delete(String sessionId) async {
    final client = ref.read(agentChatClientProvider);
    await client.deleteSession(sessionId);
    final current = state.valueOrNull ?? const <AgentSession>[];
    state = AsyncData([
      for (final session in current)
        if (session.id != sessionId) session,
    ]);
  }
}

// ============================================================
// Conversa
// ============================================================

enum AgentConversationStatus { idle, streaming, connectionLost }

class AgentConversationState {
  final String? sessionId;
  final List<AgentMessage> messages;
  final AgentConversationStatus status;
  final String? error;
  final bool loadingHistory;
  final bool refreshFailed;

  /// Texto que precisa voltar para o campo de digitação (envio que falhou).
  final String? restoreDraft;

  /// Turno de outro cliente rodando nesta conversa ("BMO respondendo").
  final bool remoteTurn;

  const AgentConversationState({
    this.sessionId,
    this.messages = const [],
    this.status = AgentConversationStatus.idle,
    this.error,
    this.loadingHistory = false,
    this.refreshFailed = false,
    this.restoreDraft,
    this.remoteTurn = false,
  });

  bool get isBusy => status == AgentConversationStatus.streaming;

  AgentConversationState copyWith({
    String? sessionId,
    List<AgentMessage>? messages,
    AgentConversationStatus? status,
    String? error,
    bool? loadingHistory,
    bool? refreshFailed,
    String? restoreDraft,
    bool? remoteTurn,
  }) =>
      AgentConversationState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        status: status ?? this.status,
        error: error,
        loadingHistory: loadingHistory ?? this.loadingHistory,
        refreshFailed: refreshFailed ?? this.refreshFailed,
        restoreDraft: restoreDraft,
        remoteTurn: remoteTurn ?? this.remoteTurn,
      );
}

@riverpod
class AgentConversation extends _$AgentConversation {
  StreamSubscription<AgentEvent>? _sub;
  Timer? _pollTimer;
  AgentConversationState _snapshot = const AgentConversationState();
  String? _sessionId;
  String? _assistantId;
  bool _turnStarted = false;
  bool _turnEnded = true;
  bool _disposed = false;
  String? _decidingCallId;

  /// `turn_id` do turno que este app iniciou (POST) — os eventos SSE do
  /// mesmo turno são ignorados aqui.
  String? _turnId;

  /// Último `turn_completed` já atendido nesta conversa (dedupe do refetch).
  String? _handledCompletedTurn;

  /// Texto do envio em andamento — devolvido ao campo se a sessão sumiu.
  String? _pendingMessage;

  /// Mensagem otimista do envio em andamento (removida se o servidor recusar
  /// o turno com 409).
  String? _optimisticUserId;

  late AgentChatClient _client;
  late Duration _pollInterval;
  int? _projectId;

  @override
  AgentConversationState build(int? projectId) {
    final userId = ref.watch(currentUserIdProvider);

    // `ref.read` de dentro de um callback assíncrono lança se o provider foi
    // reconstruído no meio; guarda as dependências estáveis no build.
    _disposed = false;
    _projectId = projectId;
    _client = ref.read(agentChatClientProvider);
    _pollInterval = ref.read(agentChatPollIntervalProvider);
    _stopStream();
    // Sem isto um stream de turno sobrevive à saída da tela (uma subscription
    // viva por projeto visitado).
    ref.onDispose(() {
      _disposed = true;
      _stopStream();
    });

    // Turnos de outros clientes chegam pelo SSE global, com `listen` pelo
    // mesmo motivo da seleção: rebuild mataria o stream em andamento.
    ref.listen<AgentLiveTurnsState>(agentLiveTurnsProvider, (previous, next) {
      _onLiveTurns(next);
    });

    // Troca de seleção vem por `listen` (não por `watch`): rebuild no meio de
    // um turno mataria o stream em andamento.
    ref.listen<String?>(selectedAgentSessionProvider(projectId),
        (previous, next) {
      _handleSelection(next);
    });

    _sessionId = null;
    _snapshot = const AgentConversationState();
    if (userId == null) return _snapshot;

    final initial = ref.read(selectedAgentSessionProvider(projectId));
    if (initial != null) {
      _sessionId = initial;
      _snapshot = AgentConversationState(
        sessionId: initial,
        loadingHistory: true,
      );
      ref.read(agentLiveTurnsProvider.notifier).markSeen(initial);
      unawaited(_loadHistory(initial));
    }
    return _snapshot;
  }

  /// Nova (null) zera; sessão diferente cancela o stream local e carrega o
  /// histórico. A migração do turno novo cai no `==` e não recarrega nada.
  void _handleSelection(String? next) {
    if (next == _sessionId) return;
    _stopStream();
    _handledCompletedTurn = null;
    _turnId = null;
    _sessionId = next;
    if (next == null) {
      _emit(const AgentConversationState());
      return;
    }
    _emit(AgentConversationState(sessionId: next, loadingHistory: true));
    ref.read(agentLiveTurnsProvider.notifier).markSeen(next);
    unawaited(_loadHistory(next));
  }

  /// Turno de outro cliente nesta conversa: indicador "BMO respondendo" e,
  /// no fim, refetch das mensagens. Eventos do turno que este app iniciou são
  /// ignorados — o stream do POST já entrega tudo.
  void _onLiveTurns(AgentLiveTurnsState live) {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    bool isOwn(String? turnId) => turnId != null && turnId == _turnId;

    final activeTurn = live.activeTurnOf(sessionId);
    // Com o POST deste app no ar, o indicador é o do stream local.
    _setRemoteTurn(
      !_snapshot.isBusy && activeTurn != null && !isOwn(activeTurn),
    );

    final completedTurn = live.completed[sessionId];
    if (completedTurn == null) return;
    // Abrir/atualizar a conversa consome o ponto de novidade da lista.
    ref.read(agentLiveTurnsProvider.notifier).markSeen(sessionId);
    if (isOwn(completedTurn) || completedTurn == _handledCompletedTurn) return;
    _handledCompletedTurn = completedTurn;
    _setRemoteTurn(false);
    unawaited(_loadHistory(sessionId));
  }

  void _setRemoteTurn(bool value) {
    if (_snapshot.remoteTurn == value) return;
    _emit(_snapshot.copyWith(remoteTurn: value));
  }

  // ── ações ────────────────────────────────────────────────────────────────

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _snapshot.isBusy) return;

    final userMessage = AgentMessage(
      id: _nextId(),
      role: AgentRole.user,
      createdAt: DateTime.now(),
      parts: [AgentTextPart(trimmed)],
    );
    _pendingMessage = trimmed;
    _optimisticUserId = userMessage.id;
    // O servidor nega as pendências ao receber mensagem nova; o card responde
    // na hora, antes do POST.
    _startTurn(_denyPending([..._snapshot.messages, userMessage]));
    _listen(
      (client) => client.sendTurn(
        sessionId: _sessionId,
        message: trimmed,
        projectId: _projectId,
      ),
    );
  }

  void approve(String callId) => _decide(callId, approved: true);

  void deny(String callId, {String? note}) =>
      _decide(callId, approved: false, note: note);

  Future<void> cancel() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      await _client.cancel(sessionId);
    } on AgentChatException catch (e) {
      _emit(_snapshot.copyWith(error: _friendlyError(e)));
    }
  }

  /// Retry manual depois de `refreshFailed`.
  void refreshNow() {
    _emit(_snapshot.copyWith(refreshFailed: false, error: null));
    _startPolling(
      knownAssistantMessages: _assistantCount(_snapshot.messages),
      knownText: _lastAssistantText(_snapshot.messages),
    );
  }

  // ── turno ────────────────────────────────────────────────────────────────

  void _decide(String callId, {required bool approved, String? note}) {
    if (_snapshot.isBusy) return;

    final decision = approved
        ? AgentApprovalDecision.approved
        : AgentApprovalDecision.denied;
    // Otimista: o card responde ao clique antes do POST.
    _emit(_snapshot.copyWith(
      messages: _withDecision(_snapshot.messages, callId, decision),
    ));

    _decidingCallId = callId;
    _startTurn(_snapshot.messages);
    _listen(
      (client) => client.sendTurn(
        sessionId: _sessionId,
        projectId: _projectId,
        approvals: {
          callId: AgentApprovalInput(approved: approved, note: note),
        },
      ),
    );
  }

  void _startTurn(List<AgentMessage> messages) {
    final assistant = AgentMessage.streamingAssistant(_nextId());
    _assistantId = assistant.id;
    _turnStarted = false;
    _turnEnded = false;
    _emit(_snapshot.copyWith(
      messages: [...messages, assistant],
      status: AgentConversationStatus.streaming,
      error: null,
      refreshFailed: false,
    ));
  }

  void _listen(Stream<AgentEvent> Function(AgentChatClient client) open) {
    _stopStream();
    _sub = open(_client).listen(
      _onEvent,
      onError: _onStreamError,
      onDone: _onStreamDone,
      cancelOnError: false,
    );
  }

  void _onEvent(AgentEvent event) {
    switch (event) {
      case TurnStarted():
        _turnStarted = true;
        _turnId = event.turnId;
        _adoptSession(event.sessionId);
      case TextDelta():
        _appendText(event.text);
      case ReasoningDelta():
        _appendReasoning(event.text);
      case ToolStarted():
        // Retomada depois de aprovação: o call_id já tem chip numa mensagem
        // anterior e é ele que reabre, nada de chip duplicado.
        if (!_setToolStatus(event.callId, AgentToolStatus.running)) {
          _updateAssistant((parts) => [
                ...parts,
                AgentToolPart(
                  callId: event.callId,
                  name: event.name,
                  label: event.label,
                  status: AgentToolStatus.running,
                ),
              ]);
        }
      case ToolEnded():
        _setToolStatus(
          event.callId,
          event.ok ? AgentToolStatus.ok : AgentToolStatus.failed,
        );
      case RichBlockReceived():
        _updateAssistant((parts) => [
              ...parts,
              AgentRichPart(
                blockId: event.blockId,
                richType: event.richType,
                payload: event.payload,
                mutable: event.mutable,
                speech: event.speech,
              ),
            ]);
      case ApprovalRequested():
        _setToolStatus(event.callId, AgentToolStatus.awaiting);
        _updateAssistant((parts) => [
              ...parts,
              AgentApprovalPart(
                callId: event.callId,
                tool: event.tool,
                label: event.label,
                summary: event.summary,
                decision: AgentApprovalDecision.pending,
              ),
            ]);
      case TurnEnded():
        _turnEnded = true;
        _finishTurn(event.status);
      case AgentErrorEvent():
        _emit(_snapshot.copyWith(error: event.message));
      case UnknownAgentEvent():
        // Tipo novo: logado pelo parser, ignorado aqui.
        break;
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    final rollback = _decidingCallId;
    _decidingCallId = null;

    // 409 no envio de mensagem: o turno de outro cliente manda. Aprovação
    // em 409 continua caindo no rollback normal abaixo.
    if (error is AgentChatException &&
        error.errorCode == 'turn_in_progress' &&
        rollback == null) {
      _handleTurnInProgress();
      return;
    }

    _optimisticUserId = null;

    if (error is AgentChatException && error.errorCode == 'not_found') {
      final draft = _pendingMessage;
      _pendingMessage = null;
      _handleMissingSession(draft: draft);
      return;
    }
    _pendingMessage = null;

    final messages = _dropEmptyAssistant(
      rollback == null
          ? _snapshot.messages
          : _withDecision(
              _snapshot.messages, rollback, AgentApprovalDecision.pending),
    );

    if (_turnStarted && !_turnEnded) {
      // O turno segue rodando no servidor; a conexão é que caiu.
      _turnEnded = true;
      _emit(_snapshot.copyWith(
        messages: messages,
        status: AgentConversationStatus.connectionLost,
      ));
      _startPolling(
        knownAssistantMessages: _assistantCount(messages),
        knownText: _lastAssistantText(messages),
      );
      return;
    }

    _turnEnded = true;
    _emit(_snapshot.copyWith(
      messages: messages,
      status: AgentConversationStatus.idle,
      error: _friendlyError(error),
    ));
  }

  /// 409 `turn_in_progress`: o servidor já está num turno desta conversa.
  /// Nada de reenvio automático — o texto volta para o campo, o indicador
  /// "BMO respondendo" liga e o `turn_completed` libera o usuário.
  void _handleTurnInProgress() {
    final draft = _pendingMessage;
    final optimisticId = _optimisticUserId;
    _pendingMessage = null;
    _optimisticUserId = null;
    _turnStarted = false;
    _turnEnded = true;

    final messages = _dropEmptyAssistant([
      for (final message in _snapshot.messages)
        if (message.id != optimisticId) message,
    ]);

    _emit(_snapshot.copyWith(
      messages: messages,
      status: AgentConversationStatus.idle,
      error: null,
      remoteTurn: true,
      restoreDraft: draft,
    ));
  }

  void _onStreamDone() {
    if (_turnEnded) return;
    // Stream fechou sem turn.end: o turno pode continuar no servidor.
    _turnEnded = true;
    _emit(_snapshot.copyWith(status: AgentConversationStatus.connectionLost));
    _startPolling(
      knownAssistantMessages: _assistantCount(_snapshot.messages),
      knownText: _lastAssistantText(_snapshot.messages),
    );
  }

  void _finishTurn(String status) {
    _optimisticUserId = null;
    // `_turnId` fica: o `session.turn_completed` do próprio turno ainda pode
    // chegar pelo SSE e precisa ser reconhecido como nosso (e ignorado).
    _pendingMessage = null;
    // `awaiting_approval` também é idle: o input continua liberado e o card
    // pendente é só uma mensagem a mais na conversa.
    final messages = _dropEmptyAssistant(_snapshot.messages);
    _emit(_snapshot.copyWith(
      messages: messages,
      status: AgentConversationStatus.idle,
    ));
  }

  void _adoptSession(String? sessionId) {
    if (sessionId == null || sessionId == _sessionId) return;
    _sessionId = sessionId;
    _snapshot = _snapshot.copyWith(sessionId: sessionId);
    ref
        .read(selectedAgentSessionProvider(_projectId).notifier)
        .select(sessionId);
    ref.invalidate(agentSessionsProvider(_projectId));
  }

  /// A sessão selecionada não existe mais para o usuário atual (troca de
  /// perfil, sessão apagada no servidor): volta para conversa nova e avisa.
  /// [draft] devolve ao campo o texto de um envio que falhou.
  void _handleMissingSession({String? draft}) {
    _stopStream();
    _turnStarted = false;
    _turnEnded = true;
    _pendingMessage = null;
    ref.invalidate(agentSessionsProvider(_projectId));
    // Zera pelo `listen` da seleção (messages/erro do estado anterior caem).
    ref.read(selectedAgentSessionProvider(_projectId).notifier).select(null);
    _emit(_snapshot.copyWith(
      messages: const [],
      status: AgentConversationStatus.idle,
      loadingHistory: false,
      error: 'essa conversa não existe mais',
      restoreDraft: draft,
    ));
  }

  // ── polling ──────────────────────────────────────────────────────────────

  void _startPolling({
    required int knownAssistantMessages,
    required String knownText,
  }) {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    _pollTimer?.cancel();
    var attempt = 0;

    void schedule() {
      _pollTimer = Timer(_pollInterval, () async {
        if (_disposed || _sessionId != sessionId) return;
        attempt++;
        try {
          final messages = await _client.fetchMessages(sessionId);
          if (_disposed || _sessionId != sessionId) return;
          if (_hasNewerAssistant(
            messages,
            knownAssistantMessages,
            knownText,
          )) {
            _emit(_snapshot.copyWith(
              messages: messages,
              status: AgentConversationStatus.idle,
              refreshFailed: false,
              error: null,
            ));
            return;
          }
        } catch (_) {
          // Segue tentando até o limite.
        }
        if (attempt >= kAgentChatPollAttempts) {
          _emit(_snapshot.copyWith(
            status: AgentConversationStatus.idle,
            refreshFailed: true,
          ));
          return;
        }
        schedule();
      });
    }

    schedule();
  }

  // ── histórico ────────────────────────────────────────────────────────────

  Future<void> _loadHistory(String sessionId) async {
    try {
      final messages = await _client.fetchMessages(sessionId);
      if (_disposed || _sessionId != sessionId) return;
      _emit(_snapshot.copyWith(messages: messages, loadingHistory: false));
    } on AgentChatException catch (e) {
      if (_disposed || _sessionId != sessionId) return;
      if (e.errorCode == 'not_found') {
        _handleMissingSession();
        return;
      }
      _emit(_snapshot.copyWith(
        loadingHistory: false,
        error: _friendlyError(e),
      ));
    } catch (e) {
      if (_disposed || _sessionId != sessionId) return;
      _emit(_snapshot.copyWith(
        loadingHistory: false,
        error: 'falha ao carregar a conversa: $e',
      ));
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  void _appendText(String delta) {
    if (delta.isEmpty) return;
    _updateAssistant((parts) {
      if (parts.isNotEmpty && parts.last is AgentTextPart) {
        final last = parts.last as AgentTextPart;
        return [...parts.take(parts.length - 1), AgentTextPart(last.text + delta)];
      }
      return [...parts, AgentTextPart(delta)];
    });
  }

  void _appendReasoning(String delta) {
    if (delta.isEmpty) return;
    _updateAssistant((parts) {
      if (parts.isNotEmpty && parts.last is AgentReasoningPart) {
        final last = parts.last as AgentReasoningPart;
        return [
          ...parts.take(parts.length - 1),
          AgentReasoningPart(last.text + delta),
        ];
      }
      return [...parts, AgentReasoningPart(delta)];
    });
  }

  void _updateAssistant(List<AgentPart> Function(List<AgentPart>) transform) {
    final assistantId = _assistantId;
    if (assistantId == null || _turnEnded) return;
    final messages = [
      for (final message in _snapshot.messages)
        if (message.isAssistant && message.id == assistantId)
          message.copyWith(parts: transform(message.parts))
        else
          message,
    ];
    _emit(_snapshot.copyWith(messages: messages));
  }

  /// Decisão otimista (e o rollback): o card e o chip do mesmo `call_id`
  /// andam juntos — `pending` = chip aguardando, `approved` = rodando,
  /// `denied` = negado.
  List<AgentMessage> _withDecision(
    List<AgentMessage> messages,
    String callId,
    AgentApprovalDecision decision, {
    bool ignored = false,
  }) =>
      [
        for (final message in messages)
          if (message.isAssistant)
            message.copyWith(parts: [
              for (final part in message.parts)
                if (part is AgentApprovalPart && part.callId == callId)
                  part.copyWith(
                    decision: decision,
                    ignored: ignored || part.ignored,
                  )
                else if (part is AgentToolPart && part.callId == callId)
                  part.copyWith(status: _toolStatusFor(decision))
                else
                  part,
            ])
          else
            message,
      ];

  AgentApprovalDecision? _approvalDecisionOf(String callId) {
    for (final message in _snapshot.messages) {
      for (final part in message.parts) {
        if (part is AgentApprovalPart && part.callId == callId) {
          return part.decision;
        }
      }
    }
    return null;
  }

  AgentToolStatus _toolStatusFor(AgentApprovalDecision decision) =>
      switch (decision) {
        AgentApprovalDecision.pending => AgentToolStatus.awaiting,
        AgentApprovalDecision.approved => AgentToolStatus.running,
        AgentApprovalDecision.denied => AgentToolStatus.denied,
      };

  /// Nega as aprovações ainda pendentes — o servidor faz o mesmo ao receber a
  /// mensagem nova.
  List<AgentMessage> _denyPending(List<AgentMessage> messages) {
    final pending = {
      for (final message in messages)
        for (final part in message.parts)
          if (part is AgentApprovalPart &&
              part.decision == AgentApprovalDecision.pending)
            part.callId,
    };
    var next = messages;
    for (final callId in pending) {
      next = _withDecision(
        next,
        callId,
        AgentApprovalDecision.denied,
        ignored: true,
      );
    }
    return next;
  }

  /// Atualiza o chip de um `call_id` em qualquer mensagem da sessão (o chip
  /// original da aprovação reabre no turno de retomada). `false` = não existe.
  bool _setToolStatus(String callId, AgentToolStatus status) {
    // Negação vence: o tool.end da retomada não converte o chip em falha.
    final denied = _approvalDecisionOf(callId) == AgentApprovalDecision.denied;
    if (denied) status = AgentToolStatus.denied;
    var found = false;
    final messages = <AgentMessage>[];
    for (final message in _snapshot.messages) {
      final parts = <AgentPart>[];
      var changed = false;
      for (final part in message.parts) {
        if (part is AgentToolPart && part.callId == callId) {
          parts.add(part.copyWith(status: status));
          changed = true;
        } else {
          parts.add(part);
        }
      }
      found = found || changed;
      messages.add(changed ? message.copyWith(parts: parts) : message);
    }
    if (!found) return false;
    _emit(_snapshot.copyWith(messages: messages));
    return true;
  }

  List<AgentMessage> _dropEmptyAssistant(List<AgentMessage> messages) => [
        for (final message in messages)
          if (!(message.isAssistant &&
              message.id == _assistantId &&
              message.parts.isEmpty))
            message,
      ];

  int _assistantCount(List<AgentMessage> messages) =>
      messages.where((m) => m.isAssistant && m.parts.isNotEmpty).length;

  String _lastAssistantText(List<AgentMessage> messages) {
    for (final message in messages.reversed) {
      if (message.isAssistant && message.parts.isNotEmpty) {
        return message.plainText;
      }
    }
    return '';
  }

  /// O servidor ganhou mensagem do assistente depois da última conhecida —
  /// mais uma, ou a mesma cresceu quando o turno terminou.
  bool _hasNewerAssistant(
    List<AgentMessage> messages,
    int knownCount,
    String knownText,
  ) =>
      _assistantCount(messages) > knownCount ||
      (_lastAssistantText(messages) != '' &&
          _lastAssistantText(messages) != knownText);

  void _emit(AgentConversationState next) {
    _snapshot = next;
    if (_disposed) return;
    try {
      state = next;
    } on StateError {
      // Provider descartado no meio de um callback assíncrono do stream.
      _disposed = true;
    }
  }

  void _stopStream() {
    _sub?.cancel();
    _sub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  int _idSeq = 0;

  /// Ids locais precisam ser únicos: no web `DateTime.now()` só tem
  /// resolução de milissegundo, então o timestamp sozinho repete.
  String _nextId() =>
      'local-${_idSeq++}-${DateTime.now().microsecondsSinceEpoch}';

  String _friendlyError(Object error) {
    if (error is AgentChatException) {
      return switch (error.errorCode) {
        'not_found' => 'sessão não encontrada',
        'turn_in_progress' => 'já existe um turno rodando nesta conversa',
        'agent_unavailable' => 'o agente está indisponível',
        _ => error.message,
      };
    }
    return 'conexão caiu: $error';
  }
}
