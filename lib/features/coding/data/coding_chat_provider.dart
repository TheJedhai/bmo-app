import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_event.dart';
import '../../chat/data/chat_message.dart';
import '../../chat/providers/chat_providers.dart';
import '../../../core/identity/identity_state.dart';

/// Controller de chat para uma conversa de coding.
///
/// Diferente do [ChatController] da feature chat, este notifier é keyed
/// diretamente pelo UUID da sessão (campo `id` do [CodingSession]) e recebe
/// o `sessionId` (bmo-xxx) como argumento de [sendMessage]. Isto evita o
/// acoplamento com [conversationsProvider] — sessões de coding não são
/// criadas via POST /api/chats e podem não aparecer na listagem de conversas.
class CodingChatNotifier extends FamilyNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatEvent>? _subscription;
  String? _currentAssistantMessageId;
  String? _currentReasoningMessageId;
  String? _currentTextMessageId;
  bool _historyLoaded = false;

  /// O UUID da sessão (usado em GET /api/chats/{uuid} para carregar
  /// histórico).
  String get _uuid => arg;

  @override
  List<ChatMessage> build(String arg) {
    ref.watch(currentUserIdProvider);
    _resetStreamState();
    _historyLoaded = false;
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const [];
  }

  /// Carrega o histórico do servidor. Chamadas subsequentes viram no-op.
  Future<void> loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;

    final client = ref.read(bmoChatClientProvider);
    try {
      final raw = await client.getChat(_uuid);
      final messages = _parseHistory(raw);
      state = messages;
    } catch (e) {
      developer.log(
        'loadHistory falhou para $_uuid: $e',
        name: 'coding_chat',
        level: 900,
      );
    }
  }

  /// Envia mensagem do usuário e escuta o stream SSE de resposta.
  ///
  /// [sessionId] é o `sessionId` do [CodingSession] (formato bmo-xxx),
  /// usado pelo POST /api/chat.
  void sendMessage(String userText, {required String sessionId}) {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) return;

    final userMsg = ChatMessage.create(
      role: ChatRole.user,
      text: trimmed,
      status: ChatMessageStatus.completed,
    );
    final assistantMsg = ChatMessage.create(
      role: ChatRole.assistant,
      text: '',
      status: ChatMessageStatus.streaming,
    );

    state = [...state, userMsg, assistantMsg];

    _currentAssistantMessageId = assistantMsg.id;
    _currentReasoningMessageId = null;
    _currentTextMessageId = null;

    final client = ref.read(bmoChatClientProvider);
    final stream = client.sendMessage(
      sessionId: sessionId,
      text: trimmed,
    );

    _subscription = stream.listen(
      (event) => _handleEvent(event),
      onError: (e) {
        _updateAssistant((m) => m.copyWith(
              text: 'erro: $e',
              status: ChatMessageStatus.error,
            ));
        _resetStreamState();
      },
    );
  }

  void cancelCurrentRequest() {
    if (_subscription == null) return;
    _subscription!.cancel();
    _updateAssistant((m) => m.copyWith(status: ChatMessageStatus.cancelled));
    _resetStreamState();
  }

  // ============================================================
  // Event handling (mesmo protocolo do ChatController)
  // ============================================================

  void _handleEvent(ChatEvent event) {
    switch (event) {
      case ResponseCreated():
      case ResponseInProgress():
        break;
      case MessageStarted(:final messageId, :final messageType):
        if (messageType == 'reasoning') {
          _currentReasoningMessageId = messageId;
        } else if (messageType == 'message') {
          _currentTextMessageId = messageId;
        }
      case TextDelta(:final messageId, :final text):
        if (messageId == _currentReasoningMessageId) {
          _updateAssistant((m) => m.copyWith(
                reasoning: (m.reasoning ?? '') + text,
              ));
        } else if (messageId == _currentTextMessageId) {
          _updateAssistant((m) => m.copyWith(text: m.text + text));
        }
      case MessageCompleted():
        break;
      case ResponseCompleted():
        _updateAssistant(
            (m) => m.copyWith(status: ChatMessageStatus.completed));
        _resetStreamState();
      case StreamError(:final error):
        _updateAssistant((m) => m.copyWith(
              text: error,
              status: ChatMessageStatus.error,
            ));
        _resetStreamState();
      case UnknownEvent():
        break;
    }
  }

  // ============================================================
  // Helpers (mesma lógica do ChatController)
  // ============================================================

  void _updateAssistant(ChatMessage Function(ChatMessage) transform) {
    final id = _currentAssistantMessageId;
    if (id == null) return;
    final idx = state.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final updated = List<ChatMessage>.from(state);
    updated[idx] = transform(updated[idx]);
    state = updated;
  }

  void _resetStreamState() {
    _subscription = null;
    _currentAssistantMessageId = null;
    _currentReasoningMessageId = null;
    _currentTextMessageId = null;
  }

  List<ChatMessage> _parseHistory(Map<String, dynamic> raw) {
    final rawMessages = raw['messages'];
    if (rawMessages is! List) {
      developer.log(
        'campo "messages" ausente ou não é lista no histórico de $_uuid',
        name: 'coding_chat',
        level: 900,
      );
      return const [];
    }

    final result = <ChatMessage>[];
    String? pendingReasoning;

    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final type = raw['type'] as String?;
      final role = raw['role'] as String?;
      final text = _extractText(raw['content']);

      if (type == 'reasoning' && role == 'assistant') {
        pendingReasoning = (pendingReasoning ?? '') + text;
        continue;
      }

      if (type == 'message' && role == 'user') {
        result.add(ChatMessage.create(
          role: ChatRole.user,
          text: text,
          status: ChatMessageStatus.completed,
        ));
        continue;
      }

      if (type == 'message' && role == 'assistant') {
        result.add(ChatMessage.create(
          role: ChatRole.assistant,
          text: text,
          reasoning: pendingReasoning,
          status: ChatMessageStatus.completed,
        ));
        pendingReasoning = null;
        continue;
      }
    }

    if (pendingReasoning != null) {
      result.add(ChatMessage.create(
        role: ChatRole.assistant,
        text: '',
        reasoning: pendingReasoning,
        status: ChatMessageStatus.completed,
      ));
    }

    return result;
  }

  String _extractText(dynamic content) {
    if (content is! List) return '';
    final buffer = StringBuffer();
    for (final item in content) {
      if (item is Map && item['type'] == 'text') {
        final t = item['text'];
        if (t is String) buffer.write(t);
      }
    }
    return buffer.toString();
  }
}

/// Provider família keyed pelo UUID da sessão de coding (campo `id` do
/// [CodingSession]). Para obter o UUID a partir do `sessionId` (bmo-xxx)
/// que vem na rota, leia [sessionsProvider] com o projectId.
final codingChatControllerProvider =
    NotifierProvider.family<CodingChatNotifier, List<ChatMessage>, String>(
  CodingChatNotifier.new,
);
