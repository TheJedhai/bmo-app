import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/data/chat_message.dart';
import '../../chat/providers/chat_providers.dart';

/// Controller de chat para uma conversa de coding.
///
/// Diferente do [ChatController] da feature chat, este notifier é keyed
/// diretamente pelo UUID da sessão (campo `id` do [CodingSession]) e recebe
/// o `sessionId` (bmo-xxx) como argumento de [sendMessage]. Isto evita o
/// acoplamento com [conversationsProvider] — sessões de coding não são
/// criadas via POST /api/chats e podem não aparecer na listagem de conversas.
class CodingChatNotifier extends BaseChatNotifier {
  /// Envia mensagem do usuário e escuta o stream SSE de resposta.
  ///
  /// [sessionId] é o `sessionId` do [CodingSession] (formato bmo-xxx),
  /// usado pelo POST /api/chat.
  void sendMessage(String userText, {required String sessionId}) {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) return;
    startStream(trimmed, sessionId: sessionId);
  }
}

/// Provider família keyed pelo UUID da sessão de coding (campo `id` do
/// [CodingSession]). Para obter o UUID a partir do `sessionId` (bmo-xxx)
/// que vem na rota, leia [sessionsProvider] com o projectId.
final codingChatControllerProvider =
    NotifierProvider.family<CodingChatNotifier, List<ChatMessage>, String>(
  CodingChatNotifier.new,
);
