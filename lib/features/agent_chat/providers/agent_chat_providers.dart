import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/agent_chat_client.dart';
import '../data/agent_event.dart';
import '../data/agent_message.dart';
import '../data/agent_session.dart';

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
final selectedAgentSessionProvider = StateProvider<String?>((ref) => null);

// ============================================================
// Lista de sessões
// ============================================================

@riverpod
class AgentSessions extends _$AgentSessions {
  @override
  Future<List<AgentSession>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final client = ref.watch(agentChatClientProvider);
    final sessions = await client.listSessions();
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

enum AgentConversationStatus { idle, streaming, awaitingApproval, connectionLost }

class AgentConversationState {
  final String? sessionId;
  final List<AgentMessage> messages;
  final AgentConversationStatus status;
  final String? error;
  final bool loadingHistory;
  final bool refreshFailed;

  const AgentConversationState({
    this.sessionId,
    this.messages = const [],
    this.status = AgentConversationStatus.idle,
    this.error,
    this.loadingHistory = false,
    this.refreshFailed = false,
  });

  bool get isBusy => status == AgentConversationStatus.streaming;

  bool get awaitsApproval =>
      status == AgentConversationStatus.awaitingApproval;

  AgentConversationState copyWith({
    String? sessionId,
    List<AgentMessage>? messages,
    AgentConversationStatus? status,
    String? error,
    bool? loadingHistory,
    bool? refreshFailed,
  }) =>
      AgentConversationState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        status: status ?? this.status,
        error: error,
        loadingHistory: loadingHistory ?? this.loadingHistory,
        refreshFailed: refreshFailed ?? this.refreshFailed,
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
  late AgentChatClient _client;
  late Duration _pollInterval;

  @override
  AgentConversationState build() {
    final userId = ref.watch(currentUserIdProvider);

    // `ref.read` de dentro de um callback assíncrono lança se o provider foi
    // reconstruído no meio; guarda as dependências estáveis no build.
    _disposed = false;
    _client = ref.read(agentChatClientProvider);
    _pollInterval = ref.read(agentChatPollIntervalProvider);
    _stopStream();

    // Troca de seleção vem por `listen` (não por `watch`): rebuild no meio de
    // um turno mataria o stream em andamento.
    ref.listen<String?>(selectedAgentSessionProvider, (previous, next) {
      _handleSelection(next);
    });

    _sessionId = null;
    _snapshot = const AgentConversationState();
    if (userId == null) return _snapshot;

    final initial = ref.read(selectedAgentSessionProvider);
    if (initial != null) {
      _sessionId = initial;
      _snapshot = AgentConversationState(
        sessionId: initial,
        loadingHistory: true,
      );
      unawaited(_loadHistory(initial));
    }
    return _snapshot;
  }

  /// Nova (null) zera; sessão diferente cancela o stream local e carrega o
  /// histórico. A migração do turno novo cai no `==` e não recarrega nada.
  void _handleSelection(String? next) {
    if (next == _sessionId) return;
    _stopStream();
    _sessionId = next;
    if (next == null) {
      _emit(const AgentConversationState());
      return;
    }
    _emit(AgentConversationState(sessionId: next, loadingHistory: true));
    unawaited(_loadHistory(next));
  }

  // ── ações ────────────────────────────────────────────────────────────────

  void send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _snapshot.isBusy || _snapshot.awaitsApproval) return;

    final userMessage = AgentMessage(
      id: _nextId(),
      role: AgentRole.user,
      createdAt: DateTime.now(),
      parts: [AgentTextPart(trimmed)],
    );
    _startTurn([..._snapshot.messages, userMessage]);
    _listen(
      (client) => client.sendTurn(sessionId: _sessionId, message: trimmed),
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
        _adoptSession(event.sessionId);
      case TextDelta():
        _appendText(event.text);
      case ReasoningDelta():
        _appendReasoning(event.text);
      case ToolStarted():
        _updateAssistant((parts) => [
              ...parts,
              AgentToolPart(
                callId: event.callId,
                name: event.name,
                label: event.label,
                status: AgentToolStatus.running,
              ),
            ]);
      case ToolEnded():
        _updateAssistant((parts) => [
              for (final part in parts)
                if (part is AgentToolPart && part.callId == event.callId)
                  part.copyWith(
                    status:
                        event.ok ? AgentToolStatus.ok : AgentToolStatus.failed,
                  )
                else
                  part,
            ]);
      case RichBlockReceived():
        _updateAssistant((parts) => [
              ...parts,
              AgentRichPart(
                blockId: event.blockId,
                richType: event.richType,
                payload: event.payload,
                mutable: event.mutable,
              ),
            ]);
      case ApprovalRequested():
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
    final messages = _dropEmptyAssistant(_snapshot.messages);
    final next = switch (status) {
      'awaiting_approval' => AgentConversationStatus.awaitingApproval,
      _ => AgentConversationStatus.idle,
    };
    _emit(_snapshot.copyWith(messages: messages, status: next));
  }

  void _adoptSession(String? sessionId) {
    if (sessionId == null || sessionId == _sessionId) return;
    _sessionId = sessionId;
    _snapshot = _snapshot.copyWith(sessionId: sessionId);
    ref.read(selectedAgentSessionProvider.notifier).state = sessionId;
    ref.invalidate(agentSessionsProvider);
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
    if (assistantId == null) return;
    final messages = [
      for (final message in _snapshot.messages)
        if (message.id == assistantId)
          message.copyWith(parts: transform(message.parts))
        else
          message,
    ];
    _emit(_snapshot.copyWith(messages: messages));
  }

  List<AgentMessage> _withDecision(
    List<AgentMessage> messages,
    String callId,
    AgentApprovalDecision decision,
  ) =>
      [
        for (final message in messages)
          message.copyWith(parts: [
            for (final part in message.parts)
              if (part is AgentApprovalPart && part.callId == callId)
                part.copyWith(decision: decision)
              else
                part,
          ]),
      ];

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

  String _nextId() => 'local-${DateTime.now().microsecondsSinceEpoch}';

  String _friendlyError(Object error) {
    if (error is AgentChatException) {
      return switch (error.errorCode) {
        'not_found' => 'sessão não encontrada',
        'turn_in_progress' => 'já existe um turno rodando nesta conversa',
        'awaiting_approval' => 'responda a aprovação acima',
        'agent_unavailable' => 'o agente está indisponível',
        _ => error.message,
      };
    }
    return 'conexão caiu: $error';
  }
}
