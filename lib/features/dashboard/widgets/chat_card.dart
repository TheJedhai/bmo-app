import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_router.dart';

import 'bmo_density.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../agent_chat/data/agent_session.dart';
import '../../agent_chat/providers/agent_chat_providers.dart';

/// Card de atalho para a aba Chat (v2).
///
/// Mostra as sessões mais recentes (título truncado, em Inter).
/// Se não houver sessões, exibe "Nenhuma conversa ainda" em textMuted
/// — mas o card continua clicável.
/// Toque numa sessão → seleciona e abre `/chat`.
class ChatCard extends ConsumerWidget {
  const ChatCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(agentSessionsProvider);

    return sessionsAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (sessions) => _ChatContent(
        sessions: sessions,
        accent: accent,
        onNewChat: () {
          ref.read(selectedAgentSessionProvider.notifier).state = null;
          appRouter.push('/chat');
        },
      ),
    );
  }
}

class _ChatContent extends StatelessWidget {
  const _ChatContent({
    required this.sessions,
    required this.accent,
    required this.onNewChat,
  });

  final List<AgentSession> sessions;
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
        if (sessions.isEmpty)
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
          ...sessions.take(BmoDensity.of(context).isCompact ? 2 : 3).map(
                (session) => _SessionRow(session: session),
              ),
        ],
      ],
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final AgentSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(selectedAgentSessionProvider.notifier).state = session.id;
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
                    session.title,
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
