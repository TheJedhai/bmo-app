import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/features/agent_chat/widgets/agent_session_list.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_frame.dart';
import '../data/coding_providers.dart';
import '../data/coding_task_providers.dart';
import '../data/models/coding_project.dart';
import '../data/models/coding_run.dart';
import '../data/models/coding_task.dart';
import 'widgets/coding_run_look.dart';
import 'widgets/coding_task_look.dart';

const _kConversationsWidth = 320.0;

/// Tela de um projeto de coding — `/coding/:projectId`.
///
/// Conversas = sessões do chat v2 do projeto (abrem `/coding/N/chat`);
/// tarefas = lista ao vivo de `coding.task.*` (abrem `/coding/tasks/N`).
class CodingProjectScreen extends ConsumerWidget {
  final int projectId;

  const CodingProjectScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate opt-in: mesmo padrão de `coding_screen.dart`.
    final features = ref.watch(enabledFeaturesProvider);
    if (!features.contains('coding')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) GoRouter.of(context).go('/');
      });
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < kMobileBreakpoint;

    // Conversa de projeto vive sob /coding/:projectId — a aba Chat é só o
    // chat principal. `go` para a URL refletir e o reload retomar no chat.
    void openChat() => GoRouter.of(context).go('/coding/$projectId/chat');

    final conversations = AgentSessionList(
      projectId: projectId,
      onItemTap: openChat,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(projectId: projectId),
          Expanded(
            child: isMobile
                ? Column(
                    children: [
                      Expanded(child: conversations),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: BmoColors.textMuted.withValues(alpha: 0.2),
                      ),
                      Expanded(child: _TasksPane(projectId: projectId)),
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: _kConversationsWidth,
                        child: conversations,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: BmoColors.textMuted.withValues(alpha: 0.2),
                      ),
                      Expanded(child: _TasksPane(projectId: projectId)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final int projectId;

  const _Header({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).valueOrNull;
    CodingProject? project;
    for (final candidate in projects ?? const <CodingProject>[]) {
      if (candidate.id == projectId) project = candidate;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                GoRouter.of(context).go('/coding');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              project?.name.toUpperCase() ?? 'PROJETO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 14,
                color: BmoColors.accentGreen,
                shadows: [
                  Shadow(
                    color: BmoColors.accentGreen.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'configurações',
            onPressed: () =>
                GoRouter.of(context).go('/coding/$projectId/settings'),
            icon: const Icon(Icons.settings_outlined, size: 18),
            color: BmoColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _TasksPane extends ConsumerWidget {
  final int projectId;

  const _TasksPane({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(codingTasksProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
          child: Row(
            children: [
              Text(
                'TAREFAS',
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: BmoColors.accentGreen.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'atualizar',
                iconSize: 16,
                color: BmoColors.textMuted,
                onPressed: () => ref.invalidate(codingTasksProvider(projectId)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BmoColors.accentGreen,
              ),
            ),
            error: (error, _) => Center(
              child: Text(
                'falha ao carregar tarefas: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.textSecondary,
                ),
              ),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma tarefa ainda',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: BmoColors.textMuted,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: tasks.length,
                itemBuilder: (context, index) => _TaskCard(task: tasks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CodingTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final look = codingTaskLook(task.status);
    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: look.color.withValues(alpha: 0.25)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // `go` (não `push`): a URL reflete o detalhe da tarefa.
        onTap: () => GoRouter.of(context).go('/coding/tasks/${task.taskId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CodingTaskStatusIcon(status: task.status, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.objective,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    ),
                    if (task.lastEvent != null && task.lastEvent!.isNotEmpty)
                      Text(
                        task.lastEvent!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: BmoColors.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        look.label,
                        if (task.stepsTotal > 0)
                          formatStepProgress(task.currentStep, task.stepsTotal),
                        formatRunTimestamp(task.startedAt ?? task.createdAt),
                        formatRunCost(task.costUsd),
                      ].where((part) => part.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: look.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: BmoColors.textMuted.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
