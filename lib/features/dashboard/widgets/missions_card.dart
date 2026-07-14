import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../missions/data/models/task.dart';
import '../../missions/data/missions_providers.dart';
import 'dash_card.dart';

/// Card de missões pendentes.
///
/// Mostra a contagem de tarefas pendentes em destaque e as próximas 3
/// tarefas com prazo mais próximo, com cores de urgência (hoje = amarelo,
/// amanhã = azul, atrasada = vermelho). Toque via DashCard onTap.
class MissionsCard extends ConsumerWidget {
  const MissionsCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(
      tasksProvider(const (
        status: 'pending',
        folderId: null,
        parentId: 0,
        includeSubtasks: true,
      )),
    );

    return tasksAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (tasks) => _MissionsContent(tasks: tasks, accent: accent),
    );
  }
}

class _MissionsContent extends StatelessWidget {
  const _MissionsContent({required this.tasks, required this.accent});

  final List<Task> tasks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pendingCount = tasks.length;

    final withDue =
        tasks.where((t) => t.dueDate != null).toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
    final upcoming = withDue.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contagem em destaque
        DashCard.highlightNumber('$pendingCount', accent),
        const SizedBox(height: 4),
        Text(
          pendingCount == 1 ? 'tarefa pendente' : 'tarefas pendentes',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: BmoColors.textMuted, height: 1),
          const SizedBox(height: 12),
          ...upcoming.map((task) => _TaskRow(task: task)),
        ] else if (pendingCount > 0) ...[
          const SizedBox(height: 16),
          Text(
            'Nenhuma tarefa com prazo definido',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  ({String label, Color? color}) _deadlineInfo(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    final diff = dueDay.difference(today).inDays;

    if (diff < 0) {
      return (label: 'atrasada', color: BmoColors.accentRed);
    }
    if (diff == 0) {
      return (label: 'hoje', color: BmoColors.accentYellow);
    }
    if (diff == 1) {
      return (label: 'amanhã', color: BmoColors.accentBlue);
    }
    return (label: 'em ${diff}d', color: null);
  }

  @override
  Widget build(BuildContext context) {
    final info =
        task.dueDate != null ? _deadlineInfo(task.dueDate!) : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (info != null)
            Text(
              info.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: info.color ?? BmoColors.textMuted,
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
