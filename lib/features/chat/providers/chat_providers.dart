import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../data/bmo_chat_client.dart';
import '../data/chat_event.dart';
import '../data/chat_message.dart';
import '../data/conversation.dart';

const String kDefaultConversationName = 'Nova conversa';

final _sessionIdRandom = Random();

String _generateSessionId() {
  final ms = DateTime.now().millisecondsSinceEpoch;
  final salt = _sessionIdRandom
      .nextInt(1 << 16)
      .toRadixString(16)
      .padLeft(4, '0');
  return 'bmo-$ms-$salt';
}

// ============================================================
// Infraestrutura HTTP
// ============================================================

// httpClientProvider is now in core/http/client_factory.dart —
// it watches currentUserIdProvider and automatically wraps with
// BmoHttpClient to add the X-User-Id header.

final bmoChatClientProvider = Provider<BmoChatClient>((ref) {
  return BmoChatClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

// ============================================================
// Lista de conversas
// ============================================================

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final client = ref.read(bmoChatClientProvider);
    final raw = await client.listChats();
    final convs = raw.map(Conversation.fromJson).toList();
    convs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return convs;
  }

  Future<Conversation> createNew() async {
    final client = ref.read(bmoChatClientProvider);
    final sessionId = _generateSessionId();
    final raw = await client.createChat(
      sessionId: sessionId,
      name: kDefaultConversationName,
    );
    final conv = Conversation.fromJson(raw);
    final current = state.valueOrNull ?? const <Conversation>[];
    state = AsyncData([conv, ...current]);
    return conv;
  }

  Future<void> delete(String uuid) async {
    final client = ref.read(bmoChatClientProvider);
    await client.deleteChat(uuid);
    final current = state.valueOrNull ?? const <Conversation>[];
    final updated = current.where((c) => c.uuid != uuid).toList();
    state = AsyncData(updated);

    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId == uuid) {
      ref.read(selectedConversationIdProvider.notifier).state =
          updated.isEmpty ? null : updated.first.uuid;
    }
  }

  Future<void> rename(String uuid, String name) async {
    final client = ref.read(bmoChatClientProvider);
    final raw = await client.renameChat(uuid, name);
    final updatedConv = Conversation.fromJson(raw);
    final current = state.valueOrNull ?? const <Conversation>[];
    final updated = [
      for (final c in current)
        if (c.uuid == uuid) updatedConv else c,
    ];
    state = AsyncData(updated);
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

// ============================================================
// Conversa selecionada
// ============================================================

final selectedConversationIdProvider = StateProvider<String?>((ref) => null);

// ============================================================
// Mensagens por conversa (família por uuid)
// ============================================================

class ChatController extends FamilyNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatEvent>? _subscription;
  String? _currentAssistantMessageId;
  String? _currentReasoningMessageId;
  String? _currentTextMessageId;
  bool _historyLoaded = false;
  bool _renameDispatched = false;

  String get _uuid => arg;

  @override
  List<ChatMessage> build(String arg) {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const [];
  }

  /// Carrega o histórico do servidor uma vez. Chamadas subsequentes viram
  /// no-op (use ref.invalidate(chatControllerProvider(uuid)) para forçar).
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
        name: 'chat_controller',
        level: 900,
      );
      // mantém state como []
    }
  }

  void sendMessage(String userText) {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) return;

    final conversations =
        ref.read(conversationsProvider).valueOrNull ?? const <Conversation>[];
    final conv = conversations.firstWhere(
      (c) => c.uuid == _uuid,
      orElse: () => throw StateError('conversa $_uuid não encontrada'),
    );

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
    _renameDispatched = false;

    final client = ref.read(bmoChatClientProvider);
    final stream = client.sendMessage(
      sessionId: conv.sessionId,
      text: trimmed,
    );

    _subscription = stream.listen(
      (event) {
        _handleEvent(event, userText: trimmed);
      },
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

  void clearChat() {
    if (_subscription != null) {
      _subscription!.cancel();
      _updateAssistant((m) => m.copyWith(status: ChatMessageStatus.cancelled));
      _resetStreamState();
    }
    state = const [];
  }

  void _handleEvent(ChatEvent event, {required String userText}) {
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
        _updateAssistant((m) => m.copyWith(status: ChatMessageStatus.completed));
        _resetStreamState();
        _maybeAutoRename(userText);
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

  /// Dispara após primeira ResponseCompleted, se a conversa ainda tem o
  /// nome default e o histórico tem exatamente 1 user + 1 assistant
  /// (ambos completed). Tenta título via LLM; cai pra truncate(40) se
  /// falhar.
  void _maybeAutoRename(String userText) {
    if (_renameDispatched) return;

    if (state.length != 2) return;
    final first = state[0];
    final second = state[1];
    if (first.role != ChatRole.user ||
        first.status != ChatMessageStatus.completed) {
      return;
    }
    if (second.role != ChatRole.assistant ||
        second.status != ChatMessageStatus.completed) {
      return;
    }

    final conversations =
        ref.read(conversationsProvider).valueOrNull ?? const <Conversation>[];
    final conv = conversations.firstWhere(
      (c) => c.uuid == _uuid,
      orElse: () => throw StateError('conv $_uuid sumiu'),
    );
    if (conv.name != kDefaultConversationName) return;

    _renameDispatched = true;
    final assistantText = second.text;
    final fallback =
        userText.length > 40 ? userText.substring(0, 40) : userText;

    // Fire and forget: tenta LLM, cai pro fallback se vier null.
    () async {
      final client = ref.read(bmoChatClientProvider);
      final llmTitle = await client.suggestTitle(
        userMessage: userText,
        assistantMessage: assistantText,
      );
      final newName = llmTitle ?? fallback;
      try {
        await ref
            .read(conversationsProvider.notifier)
            .rename(_uuid, newName);
      } catch (e) {
        developer.log(
          'auto-rename rename() falhou para $_uuid: $e',
          name: 'chat_controller',
          level: 900,
        );
      }
    }();
  }

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

  /// Converte o histórico cru do servidor em ChatMessages.
  /// Sequência típica de um turno: (user/message) → (assistant/reasoning)
  /// → (assistant/message). O reasoning fica anexado à message do
  /// assistant que vem em seguida.
  List<ChatMessage> _parseHistory(Map<String, dynamic> raw) {
    final rawMessages = raw['messages'];
    if (rawMessages is! List) {
      developer.log(
        'campo "messages" ausente ou não é lista no histórico de $_uuid',
        name: 'chat_controller',
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

    // Reasoning órfão (sem message depois) — emite mesmo assim.
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

final chatControllerProvider =
    NotifierProvider.family<ChatController, List<ChatMessage>, String>(
  ChatController.new,
);

// ============================================================
// Mensagens da conversa atualmente selecionada
// ============================================================

final currentMessagesProvider = Provider<List<ChatMessage>>((ref) {
  final id = ref.watch(selectedConversationIdProvider);
  if (id == null) return const [];
  return ref.watch(chatControllerProvider(id));
});
