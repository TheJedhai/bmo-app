import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bmo_theme.dart';
import 'data/chat_message.dart';
import 'providers/chat_providers.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_message_list.dart';
import 'widgets/sidebar_layout.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-seleciona a conversa mais recente assim que a lista carrega.
    ref.listenManual(conversationsProvider, (prev, next) {
      next.whenData((convs) {
        final selectedId = ref.read(selectedConversationIdProvider);
        if (selectedId == null && convs.isNotEmpty) {
          ref.read(selectedConversationIdProvider.notifier).state =
              convs.first.uuid;
        }
      });
    });

    // Carrega histórico quando uma conversa é selecionada.
    ref.listenManual<String?>(
      selectedConversationIdProvider,
      (prev, next) {
        if (next == null) return;
        ref.read(chatControllerProvider(next).notifier).loadHistory();
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SidebarLayout(child: _ChatBody());
  }
}

class _ChatBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedConversationIdProvider);

    if (selectedId == null) {
      return _NoConversationState(theme: theme);
    }

    final messages = ref.watch(currentMessagesProvider);
    final controller = ref.read(chatControllerProvider(selectedId).notifier);

    final last = messages.isEmpty ? null : messages.last;
    final isStreaming = last != null &&
        last.role == ChatRole.assistant &&
        last.status == ChatMessageStatus.streaming;

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _EmptyConversationState(theme: theme)
              : ChatMessageList(messages: messages),
        ),
        Divider(
          color: BmoColors.textMuted.withValues(alpha: 0.2),
          height: 1,
          thickness: 1,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ChatInput(
            isStreaming: isStreaming,
            onSend: controller.sendMessage,
            onCancel: controller.cancelCurrentRequest,
          ),
        ),
      ],
    );
  }
}

class _NoConversationState extends StatelessWidget {
  final ThemeData theme;
  const _NoConversationState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('BMO PRONTO', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Selecione ou crie uma conversa pra começar',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversationState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyConversationState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('manda uma mensagem aí', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'BMO está pronto',
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
