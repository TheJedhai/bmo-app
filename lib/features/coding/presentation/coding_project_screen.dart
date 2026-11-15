import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/features/agent_chat/widgets/agent_session_list.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_frame.dart';
import '../data/coding_providers.dart';
import '../data/coding_run_providers.dart';
import '../data/models/coding_project.dart';
import '../data/models/coding_run.dart';
import 'widgets/coding_run_look.dart';

const _kConversationsWidth = 320.0;

/// Tela de um projeto de coding — `/coding/:projectId`.
///
/// Conversas = sessões do chat v2 do projeto (abrem `/chat?project=N`);
/// execuções = histórico de runs autônomos (abrem `/coding/runs/N`).
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

    void openChat() => GoRouter.of(context).push('/chat?project=$projectId');

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
                      Expanded(child: _RunsPane(projectId: projectId)),
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
                      Expanded(child: _RunsPane(projectId: projectId)),
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
        ],
      ),
    );
  }
}

class _RunsPane extends ConsumerWidget {
  final int projectId;

  const _RunsPane({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(codingRunsProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
          child: Row(
            children: [
              Text(
                'EXECUÇÕES',
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
                onPressed: () => ref.invalidate(codingRunsProvider(projectId)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: runsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BmoColors.accentGreen,
              ),
            ),
            error: (error, _) => Center(
              child: Text(
                'falha ao carregar runs: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.textSecondary,
                ),
              ),
            ),
            data: (runs) {
              if (runs.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhum run ainda',
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
                itemCount: runs.length,
                itemBuilder: (context, index) => _RunCard(run: runs[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  final CodingRun run;

  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    final look = codingRunLook(run.status);
    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: look.color.withValues(alpha: 0.25)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GoRouter.of(context).push('/coding/runs/${run.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CodingRunStatusIcon(status: run.status, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        look.label,
                        formatRunTimestamp(run.startedAt ?? run.createdAt),
                        'duração ${formatRunDuration(run.durationMs)}',
                        formatRunCost(run.costUsd),
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
