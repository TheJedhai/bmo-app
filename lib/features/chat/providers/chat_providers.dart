import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
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
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final client = ref.watch(bmoChatClientProvider);
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

/// Callback que envia uma mensagem de eco na conversa ativa (normal ou coding).
///
/// Cada tela de chat define este callback quando sua conversa está ativa e o
/// limpa ao sair. O [BmoRichQuestionCard] (e futuros widgets que precisem ecoar
/// respostas) lê este provider para enviar a resposta sem saber qual tipo de
/// conversa está renderizando.
final activeChatEchoProvider = StateProvider<void Function(String)?>((ref) => null);

// ============================================================
// Base compartilhada para notifiers de chat (normal e coding)
// ============================================================

/// Lógica comum a [ChatController] e CodingChatNotifier:
/// stream SSE, parsing de histórico, estado da sessão.
///
/// Subclasses chamam [startStream] com o sessionId resolvido e podem
/// passar [onResponseCompleted] para ações pós-resposta (ex: auto-rename).
abstract class BaseChatNotifier
    extends FamilyNotifier<List<ChatMessage>, String> {
  StreamSubscription<ChatEvent>? streamSub;
  String? currentAssistantMessageId;
  String? currentReasoningMessageId;
  String? currentTextMessageId;
  bool historyLoaded = false;

  /// Delegações em andamento, keyed por call_id. Sincronizadas para a
  /// mensagem do assistant corrente a cada atualização.
  final Map<String, DelegationEvent> _delegations = {};

  String get chatId => arg;

  @override
  List<ChatMessage> build(String arg) {
    ref.watch(currentUserIdProvider);
    resetStreamState();
    historyLoaded = false;
    ref.onDispose(() {
      streamSub?.cancel();
    });
    return const [];
  }

  Future<void> loadHistory() async {
    if (historyLoaded) return;
    historyLoaded = true;

    final client = ref.read(bmoChatClientProvider);
    try {
      final raw = await client.getChat(chatId);
      final messages = parseHistory(raw);
      state = messages;
    } catch (e) {
      developer.log(
        'loadHistory falhou para $chatId: $e',
        name: 'base_chat',
        level: 900,
      );
    }
  }

  /// Envia mensagem e escuta o stream SSE de resposta.
  /// [sessionId] é o identificador bmo-xxx usado pelo POST /api/chat.
  /// [onResponseCompleted] dispara após ResponseCompleted (ex: auto-rename
  /// no chat normal; não usado no coding).
  void startStream(String userText, {
    required String sessionId,
    void Function()? onResponseCompleted,
  }) {
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

    currentAssistantMessageId = assistantMsg.id;
    currentReasoningMessageId = null;
    currentTextMessageId = null;

    final client = ref.read(bmoChatClientProvider);
    final stream = client.sendMessage(
      sessionId: sessionId,
      text: trimmed,
    );

    streamSub = stream.listen(
      (event) => handleEvent(event, onResponseCompleted: onResponseCompleted),
      onError: (e) {
        updateAssistant((m) => m.copyWith(
              text: 'erro: $e',
              status: ChatMessageStatus.error,
            ));
        resetStreamState();
      },
    );
  }

  void cancelCurrentRequest() {
    if (streamSub == null) return;
    streamSub!.cancel();
    updateAssistant((m) => m.copyWith(status: ChatMessageStatus.cancelled));
    resetStreamState();
  }

  // ============================================================
  // Event handling (protocolo SSE do bmo-server)
  // ============================================================

  void handleEvent(ChatEvent event, {void Function()? onResponseCompleted}) {
    switch (event) {
      case ResponseCreated():
      case ResponseInProgress():
        break;
      case MessageStarted(:final messageId, :final messageType):
        if (messageType == 'reasoning') {
          currentReasoningMessageId = messageId;
        } else if (messageType == 'message') {
          currentTextMessageId = messageId;
        }
      case TextDelta(:final messageId, :final text):
        if (messageId == currentReasoningMessageId) {
          updateAssistant((m) => m.copyWith(
                reasoning: (m.reasoning ?? '') + text,
              ));
        } else if (messageId == currentTextMessageId) {
          updateAssistant((m) => m.copyWith(text: m.text + text));
        }
      case MessageCompleted():
        break;
      case PluginCallStarted():
        break; // name só chega no content/data, chip criado no PluginCallData
      case PluginCallCompleted(:final callId, :final name, :final arguments):
        if (name == 'delegate_external_agent') {
          _applyDelegationArgs(callId, arguments);
        }
      case PluginCallData(:final callId, :final name, :final arguments):
        if (name == 'delegate_external_agent') {
          _applyDelegationArgs(callId, arguments);
        }
      case PluginCallOutput(:final callId, :final name, :final output):
        if (name == 'delegate_external_agent') {
          _applyDelegationOutput(callId, output);
        }
      case ResponseCompleted():
        updateAssistant(
            (m) => m.copyWith(status: ChatMessageStatus.completed));
        resetStreamState();
        onResponseCompleted?.call();
      case StreamError(:final error):
        updateAssistant((m) => m.copyWith(
              text: error,
              status: ChatMessageStatus.error,
            ));
        resetStreamState();
      case UnknownEvent():
        break;
    }
  }

  // ============================================================
  // Delegação (delegate_external_agent)
  // ============================================================

  /// Extrai runner e cwd dos arguments JSON do plugin_call e atualiza
  /// a delegação correspondente.
  void _applyDelegationArgs(String callId, String rawArgs) {
    final existing = _delegations[callId] ??
        DelegationEvent(callId: callId, status: DelegationStatus.running);
    String? runner;
    String? cwd;
    try {
      final args = jsonDecode(rawArgs);
      if (args is Map<String, dynamic>) {
        runner = args['runner'] as String?;
        cwd = args['cwd'] as String?;
        // Fallback para nomes alternativos comuns
        runner ??= args['agent'] as String?;
        cwd ??= args['working_dir'] as String?;
        cwd ??= args['working_directory'] as String?;
      }
    } catch (_) {
      // arguments ainda não é JSON completo (streaming) — ignora
    }
    _delegations[callId] = existing.copyWith(
      runner: runner ?? existing.runner,
      cwd: cwd ?? existing.cwd,
    );
    _syncDelegationsToAssistant();
  }

  /// Processa o output de um plugin_call_output.
  ///
  /// O output é uma string JSON contendo uma lista de blocos {type, text}.
  /// Para delegate_external_agent, há duas formas:
  /// 1. Pedido de permissão — texto começa com
  ///    "🔐 **External Agent Permission Request**"
  /// 2. Resultado final — dois blocos: runner info + `[assistant]` seguido do relatório
  void _applyDelegationOutput(String callId, String output) {
    final existing = _delegations[callId] ??
        DelegationEvent(callId: callId, status: DelegationStatus.running);
    try {
      final parsed = jsonDecode(output);
      if (parsed is! List) {
        _delegations[callId] = existing.copyWith(
          status: DelegationStatus.error,
          error: output,
        );
        _syncDelegationsToAssistant();
        return;
      }

      final blocks = parsed.cast<Map<String, dynamic>>();
      final allText = blocks
          .where((b) => b['type'] == 'text')
          .map((b) => (b['text'] as String?) ?? '')
          .join('\n');

      if (allText.contains('🔐 **External Agent Permission Request**')) {
        // Pedido de permissão — a pergunta é renderizada pelo
        // BmoRichQuestionCard, não duplicamos aqui.
        _delegations[callId] = existing.copyWith(
          status: DelegationStatus.waitingPermission,
        );
      } else if (allText.contains('[assistant]')) {
        // Resultado final: extrai o relatório após "[assistant]"
        final report =
            allText.split('[assistant]').skip(1).join('[assistant]').trim();
        _delegations[callId] = existing.copyWith(
          status: DelegationStatus.completed,
          report: report,
        );
      } else {
        // Output com formato inesperado
        _delegations[callId] = existing.copyWith(
          status: DelegationStatus.completed,
          report: allText,
        );
      }
    } catch (_) {
      // Output não é JSON válido — pode ser texto puro de erro
      _delegations[callId] = existing.copyWith(
        status: DelegationStatus.error,
        error: output,
      );
    }
    _syncDelegationsToAssistant();
  }

  /// Copia o estado atual de [_delegations] para a mensagem do assistant
  /// corrente.
  void _syncDelegationsToAssistant() {
    if (_delegations.isEmpty) return;
    updateAssistant((m) => m.copyWith(
          delegations: _delegations.values.toList(),
        ));
  }

  // ============================================================
  // Helpers
  // ============================================================

  void updateAssistant(ChatMessage Function(ChatMessage) transform) {
    final id = currentAssistantMessageId;
    if (id == null) return;
    final idx = state.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final updated = List<ChatMessage>.from(state);
    updated[idx] = transform(updated[idx]);
    state = updated;
  }

  void resetStreamState() {
    streamSub = null;
    currentAssistantMessageId = null;
    currentReasoningMessageId = null;
    currentTextMessageId = null;
    _delegations.clear();
  }

  /// Converte o histórico cru do servidor em ChatMessages.
  ///
  /// Sequência típica de um turno: (user/message) → (assistant/reasoning)
  /// → (assistant/message). O reasoning fica anexado à message do assistant
  /// que vem em seguida.
  ///
  /// Mensagens de plugin_call e plugin_call_output viram [DelegationEvent]s
  /// anexados à última mensagem do assistant.
  List<ChatMessage> parseHistory(Map<String, dynamic> raw) {
    final rawMessages = raw['messages'];
    if (rawMessages is! List) {
      developer.log(
        'campo "messages" ausente ou não é lista no histórico de $chatId',
        name: 'base_chat',
        level: 900,
      );
      return const [];
    }

    final result = <ChatMessage>[];
    String? pendingReasoning;
    final delegations = <String, DelegationEvent>{};

    void flushDelegations() {
      if (delegations.isEmpty || result.isEmpty) return;
      final last = result.last;
      if (last.role != ChatRole.assistant) return;
      result[result.length - 1] = last.copyWith(
        delegations: delegations.values.toList(),
      );
      delegations.clear();
    }

    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final type = raw['type'] as String?;
      final role = raw['role'] as String?;

      // plugin_call_output pode vir antes de flush — processa e anexa ao
      // último assistant.
      if (type == 'plugin_call_output') {
        // Campos dentro de content[].data, não no topo
        String callId = '';
        String name = '';
        String output = '';
        final content = raw['content'];
        if (content is List && content.isNotEmpty) {
          final first = content[0];
          if (first is Map) {
            final data = first['data'];
            if (data is Map) {
              callId = data['call_id'] as String? ?? '';
              name = data['name'] as String? ?? '';
              output = data['output'] as String? ?? '';
            }
          }
        }
        if (name == 'delegate_external_agent' && callId.isNotEmpty) {
          final existing = delegations[callId] ??
              DelegationEvent(callId: callId, status: DelegationStatus.running);
          delegations[callId] =
              _parseHistoryDelegationOutput(existing, output);
          flushDelegations();
        }
        continue;
      }

      if (type == 'plugin_call') {
        // Campos dentro de content[].data, não no topo
        String callId = '';
        String name = '';
        String arguments = '';
        final content = raw['content'];
        if (content is List && content.isNotEmpty) {
          final first = content[0];
          if (first is Map) {
            final data = first['data'];
            if (data is Map) {
              callId = data['call_id'] as String? ?? '';
              name = data['name'] as String? ?? '';
              arguments = data['arguments'] as String? ?? '';
            }
          }
        }
        if (name == 'delegate_external_agent' && callId.isNotEmpty) {
          final existing = delegations[callId] ??
              DelegationEvent(callId: callId, status: DelegationStatus.running);
          delegations[callId] =
              _parseHistoryDelegationArgs(existing, arguments);
          // Não faz flush aqui — espera o plugin_call_output correspondente
          // para não perder runner/cwd ao limpar o mapa antes do output.
        }
        continue;
      }

      final text = extractText(raw['content']);

      if (type == 'reasoning' && role == 'assistant') {
        pendingReasoning = (pendingReasoning ?? '') + text;
        continue;
      }

      if (type == 'message' && role == 'user') {
        flushDelegations();
        result.add(ChatMessage.create(
          role: ChatRole.user,
          text: text,
          status: ChatMessageStatus.completed,
        ));
        continue;
      }

      if (type == 'message' && role == 'assistant') {
        flushDelegations();
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

    flushDelegations();

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

  /// Extrai runner e cwd dos arguments de um plugin_call no histórico.
  DelegationEvent _parseHistoryDelegationArgs(
      DelegationEvent existing, String rawArgs) {
    try {
      final args = jsonDecode(rawArgs);
      if (args is Map<String, dynamic>) {
        String? runner = args['runner'] as String?;
        String? cwd = args['cwd'] as String?;
        runner ??= args['agent'] as String?;
        cwd ??= args['working_dir'] as String?;
        cwd ??= args['working_directory'] as String?;
        return existing.copyWith(
          runner: runner ?? existing.runner,
          cwd: cwd ?? existing.cwd,
        );
      }
    } catch (_) {}
    return existing;
  }

  /// Processa o output de um plugin_call_output no histórico.
  DelegationEvent _parseHistoryDelegationOutput(
      DelegationEvent existing, String output) {
    try {
      final parsed = jsonDecode(output);
      if (parsed is! List) {
        return existing.copyWith(
          status: DelegationStatus.error,
          error: output,
        );
      }
      final blocks = parsed.cast<Map<String, dynamic>>();
      final allText = blocks
          .where((b) => b['type'] == 'text')
          .map((b) => (b['text'] as String?) ?? '')
          .join('\n');

      if (allText.contains('🔐 **External Agent Permission Request**')) {
        return existing.copyWith(status: DelegationStatus.waitingPermission);
      } else if (allText.contains('[assistant]')) {
        final report =
            allText.split('[assistant]').skip(1).join('[assistant]').trim();
        return existing.copyWith(
          status: DelegationStatus.completed,
          report: report,
        );
      } else {
        return existing.copyWith(
          status: DelegationStatus.completed,
          report: allText,
        );
      }
    } catch (_) {
      return existing.copyWith(
        status: DelegationStatus.error,
        error: output,
      );
    }
  }

  String extractText(dynamic content) {
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

// ============================================================
// Chat normal (conversas do menu lateral)
// ============================================================

class ChatController extends BaseChatNotifier {
  bool _renameDispatched = false;

  void sendMessage(String userText) {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) return;

    final conversations =
        ref.read(conversationsProvider).valueOrNull ?? const <Conversation>[];
    final conv = conversations.firstWhere(
      (c) => c.uuid == chatId,
      orElse: () => throw StateError('conversa $chatId não encontrada'),
    );

    _renameDispatched = false;
    startStream(trimmed, sessionId: conv.sessionId,
        onResponseCompleted: () => _maybeAutoRename(trimmed));
  }

  void clearChat() {
    if (streamSub != null) {
      streamSub!.cancel();
      updateAssistant((m) => m.copyWith(status: ChatMessageStatus.cancelled));
      resetStreamState();
    }
    state = const [];
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
      (c) => c.uuid == chatId,
      orElse: () => throw StateError('conv $chatId sumiu'),
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
            .rename(chatId, newName);
      } catch (e) {
        developer.log(
          'auto-rename rename() falhou para $chatId: $e',
          name: 'chat_controller',
          level: 900,
        );
      }
    }();
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
