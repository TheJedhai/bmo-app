import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../chat/data/conversation.dart';
import '../../chat/providers/chat_providers.dart';

/// Card de atalho para a aba Chat.
///
/// Mostra as 3 conversas mais recentes (título truncado, em Inter).
/// Se não houver conversas, exibe "Nenhuma conversa ainda" em textMuted
/// — mas o card continua clicável.
/// Toque via DashCard onTap → AppTab.chat.
class ChatCard extends ConsumerWidget {
  const ChatCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (conversations) => _ChatContent(
        conversations: conversations,
        accent: accent,
      ),
    );
  }
}

class _ChatContent extends StatelessWidget {
  const _ChatContent({required this.conversations, required this.accent});

  final List<Conversation> conversations;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'Nenhuma conversa ainda',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textMuted,
            ),
          ),
        ),
      );
    }

    final recent = conversations.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.chat_bubble_outline, size: 28, color: accent),
        const SizedBox(height: 12),
        ...recent.map((conv) => _ConversationRow(conversation: conv)),
      ],
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              conversation.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '—',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 40,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Icon(
          Icons.chat_bubble_outline,
          size: 40,
          color: BmoColors.textMuted,
        ),
      ),
    );
  }
}
