import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bmo_app/features/coding/data/coding_providers.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../../../core/widgets/bmo_frame.dart';
import '../providers/agent_chat_providers.dart';
import 'agent_input.dart';
import 'agent_message_list.dart';
import 'agent_session_list.dart';

const _kSidebarWidth = 260.0;

/// Nome do projeto no cabeçalho; "Chat" enquanto a lista de projetos não
/// chegou (ou se ela falhar).
String _projectTitle(WidgetRef ref, int projectId) {
  final projects = ref.watch(projectsProvider).valueOrNull;
  for (final project in projects ?? const []) {
    if (project.id == projectId) return project.name;
  }
  return 'Chat';
}

/// Tela do chat v2, dona da rota `/chat`.
///
/// [projectId] opcional: `null` = chat principal; `N` = conversas do projeto
/// (a lista e a criação de sessão mandam `project_id` ao servidor).
///
/// Insets de top bar/nav bar vêm do `_AppShell` do router — nada de SafeArea.
class AgentChatScreen extends ConsumerStatefulWidget {
  final int? projectId;

  const AgentChatScreen({super.key, this.projectId});

  @override
  ConsumerState<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends ConsumerState<AgentChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < kMobileBreakpoint;
    final projectId = widget.projectId;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: isMobile
          ? Drawer(
              backgroundColor: BmoColors.screenBg,
              child: AgentSessionList(
                projectId: projectId,
                onItemTap: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          projectId == null ? 'Chat' : _projectTitle(ref, projectId),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: isMobile
            ? [
                IconButton(
                  icon: const Icon(Icons.menu, color: BmoColors.textPrimary),
                  onPressed: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                ),
              ]
            : null,
      ),
      body: isMobile
          ? _AgentChatBody(projectId: projectId)
          : Row(
              children: [
                SizedBox(
                  width: _kSidebarWidth,
                  child: AgentSessionList(projectId: projectId),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: BmoColors.textMuted,
                ),
                Expanded(child: _AgentChatBody(projectId: projectId)),
              ],
            ),
    );
  }
}

class _AgentChatBody extends ConsumerWidget {
  final int? projectId;

  const _AgentChatBody({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentConversationProvider(projectId));
    final notifier = ref.read(agentConversationProvider(projectId).notifier);

    final streaming =
        state.status == AgentConversationStatus.streaming;
    final connectionLost =
        state.status == AgentConversationStatus.connectionLost;

    return Column(
      children: [
        if (state.loadingHistory)
          const LinearProgressIndicator(
            minHeight: 2,
            color: BmoColors.accentGreen,
          ),
        Expanded(
          child: state.messages.isEmpty
              ? const _EmptyConversation()
              : AgentMessageList(
                  messages: state.messages,
                  streaming: streaming,
                  onApprove: notifier.approve,
                  onDeny: (callId, note) =>
                      notifier.deny(callId, note: note),
                ),
        ),
        if (connectionLost)
          _Banner(
            text: 'conexão perdida, atualizando...',
            color: BmoColors.accentYellow,
          ),
        if (state.refreshFailed)
          _Banner(
            text: 'não foi possível atualizar',
            color: BmoColors.accentRed,
            action: TextButton(
              onPressed: notifier.refreshNow,
              child: const Text('tentar de novo'),
            ),
          ),
        if (state.error != null)
          _Banner(text: state.error!, color: BmoColors.accentRed),
        Divider(
          color: BmoColors.textMuted.withValues(alpha: 0.2),
          height: 1,
          thickness: 1,
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: AgentInput(
            isStreaming: streaming,
            enabled: !streaming && !state.loadingHistory,
            draft: state.restoreDraft,
            onSend: notifier.send,
            onCancel: notifier.cancel,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? action;

  const _Banner({required this.text, required this.color, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '💬',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'fala com o BMO',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
