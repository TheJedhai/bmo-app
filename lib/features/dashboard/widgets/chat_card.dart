import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../chat/data/conversation.dart';
import '../../chat/providers/chat_providers.dart';

/// Card de atalho para a aba Chat.
///
/// Mostra as 3 conversas mais recentes (título truncado, em Inter).
/// Se não houver conversas, exibe "Nenhuma conversa ainda" em textMuted
/// — mas o card continua clicável.
/// Toque via DashCard onTap → context.push('/chat').
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
        onNewChat: () async {
          try {
            final conv =
                await ref.read(conversationsProvider.notifier).createNew();
            ref.read(selectedConversationIdProvider.notifier).state =
                conv.uuid;
            appRouter.push('/chat');
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('falha ao criar: $e')),
              );
            }
          }
        },
      ),
    );
  }
}

class _ChatContent extends StatelessWidget {
  const _ChatContent({
    required this.conversations,
    required this.accent,
    required this.onNewChat,
  });

  final List<Conversation> conversations;
  final Color accent;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: const Color(0xFF0F1115),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Novo chat',
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF0F1115),
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onNewChat,
          ),
        ),
        if (conversations.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
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
          )
        else ...[
          const SizedBox(height: 12),
          Icon(Icons.chat_bubble_outline, size: 28, color: accent),
          const SizedBox(height: 12),
          ...conversations.take(3).map(
                (conv) => _ConversationRow(conversation: conv),
              ),
        ],
      ],
    );
  }
}

class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(selectedConversationIdProvider.notifier).state =
                conversation.uuid;
            appRouter.push('/chat');
          },
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
