import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/events/events_provider.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/coding_task_providers.dart';
import '../data/models/coding_run.dart';
import '../data/models/coding_task.dart';
import 'widgets/coding_run_look.dart';
import 'widgets/coding_task_actions.dart';
import 'widgets/coding_task_look.dart';

/// Detalhe de uma tarefa — `/coding/tasks/:taskId`.
///
/// Status e números vêm ao vivo ([codingTaskLiveProvider]); os passos e as
/// tentativas vêm do REST ([codingTaskProvider]) e dos eventos
/// `coding.run.*` com `step_id`.
class CodingTaskScreen extends ConsumerWidget {
  final int taskId;

  const CodingTaskScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(codingTaskProvider(taskId));
    final live = ref.watch(codingTaskLiveProvider(taskId));

    ref.listen<int>(sseGenerationProvider, (previous, next) {
      if (previous != next) ref.invalidate(codingTaskProvider(taskId));
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(taskId: taskId),
          Expanded(
            child: snapshot.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  'falha ao carregar tarefa: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textSecondary,
                  ),
                ),
              ),
              data: (task) {
                final rawStatus = live?['status'];
                final status = codingTaskStatusFrom(
                  rawStatus is String ? rawStatus : task.status.wire,
                );
                final canJoin =
                    (live?['can_join'] as bool?) ?? task.canJoin;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    _Summary(task: task, status: status, live: live),
                    const SizedBox(height: 12),
                    CodingTaskActions(
                      taskId: taskId,
                      status: status,
                      canJoin: canJoin,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'PASSOS',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 10,
                        color: BmoColors.accentGreen.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (task.steps.isEmpty)
                      const Text(
                        'Nenhum passo na tarefa',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: BmoColors.textMuted,
                        ),
                      ),
                    for (final step in task.steps) _StepCard(step: step),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int taskId;

  const _Header({required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go('/coding');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Text(
            'TAREFA #$taskId',
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
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CodingTask task;
  final CodingTaskStatus status;
  final Map<String, dynamic>? live;

  const _Summary({
    required this.task,
    required this.status,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    final look = codingTaskLook(status);
    final cost = _double(live?['cost_usd']) ?? task.costUsd;
    final durationMs = _int(live?['duration_ms']) ?? task.durationMs;
    final lastEvent = live?['last_event']?.toString() ?? task.lastEvent;
    final errorMessage =
        live?['error_message']?.toString() ?? task.errorMessage;
    final stepsDone = _int(live?['steps_done']) ?? task.stepsDone;
    final stepsTotal = _int(live?['steps_total']) ?? task.stepsTotal;
    final currentStep = _int(live?['current_step']) ?? task.currentStep;

    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: look.color.withValues(alpha: 0.25)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CodingTaskStatusIcon(status: status, size: 18),
                const SizedBox(width: 10),
                Text(
                  look.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: look.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              task.objective,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'progresso',
              value: '${formatStepProgress(currentStep, stepsTotal)} · '
                  '$stepsDone feito(s)',
            ),
            _Field(label: 'custo', value: formatRunCost(cost)),
            _Field(label: 'duração', value: formatRunDuration(durationMs)),
            _Field(label: 'branch', value: task.branch ?? '—'),
            _Field(label: 'branch base', value: task.baseBranch ?? '—'),
            _Field(
              label: 'modelo',
              value: [task.model, task.effort]
                  .where((part) => part != null && part.isNotEmpty)
                  .join(' · ')
                  .ifEmpty('—'),
            ),
            _Field(
              label: 'quando',
              value: formatRunTimestamp(task.startedAt ?? task.createdAt),
            ),
            if (lastEvent != null && lastEvent.isNotEmpty)
              _Field(label: 'último sinal', value: lastEvent),
            _Field(
              label: 'juntada em',
              value: task.joinedAt == null
                  ? '—'
                  : formatRunTimestamp(task.joinedAt),
            ),
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'erro',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                errorMessage,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.accentRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

/// Um passo: prompt, tentativas, veredito e as tentativas vistas ao vivo
/// (abrem o detalhe do run).
class _StepCard extends ConsumerWidget {
  final CodingTaskStep step;

  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = codingStepLook(step.status);
    final runs = ref.watch(codingStepRunsProvider(step.stepId));
    final runIds = runs.keys.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: look.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(look.icon, size: 14, color: look.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${step.seq}. ${step.title}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BmoColors.textPrimary,
                  ),
                ),
              ),
              Text(
                look.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: look.color,
                ),
              ),
            ],
          ),
          if (step.prompt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.prompt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(
                icon: Icons.repeat,
                text: 'tentativas ${step.attempts}/${step.maxAttempts}',
              ),
              if (step.verdict != null)
                _Meta(icon: Icons.rule, text: 'veredito: ${step.verdict}'),
              if (step.costUsd != null)
                _Meta(
                  icon: Icons.payments_outlined,
                  text: formatRunCost(step.costUsd),
                ),
              if (step.durationMs != null)
                _Meta(
                  icon: Icons.timer_outlined,
                  text: formatRunDuration(step.durationMs),
                ),
              if (step.commitSha != null && step.commitSha!.isNotEmpty)
                _Meta(
                  icon: Icons.commit,
                  text: _shortSha(step.commitSha!),
                ),
            ],
          ),
          if (step.note != null && step.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.note!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textSecondary,
              ),
            ),
          ],
          if (step.lastError != null && step.lastError!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              step.lastError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.accentRed,
              ),
            ),
          ],
          if (runIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'TENTATIVAS',
              style: TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 8,
                color: BmoColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            for (final runId in runIds)
              _RunLink(runId: runId, patch: runs[runId]!),
          ],
        ],
      ),
    );
  }

  static String _shortSha(String sha) =>
      sha.length <= 7 ? sha : sha.substring(0, 7);
}

class _RunLink extends StatelessWidget {
  final int runId;
  final Map<String, dynamic> patch;

  const _RunLink({required this.runId, required this.patch});

  @override
  Widget build(BuildContext context) {
    final status = codingRunStatusFrom(patch['status']?.toString());
    final look = codingRunLook(status);
    final cost = patch['cost_usd_computed'];
    return InkWell(
      onTap: () => GoRouter.of(context).go('/coding/runs/$runId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(look.icon, size: 12, color: look.color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'tentativa #$runId · ${look.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: look.color,
                ),
              ),
            ),
            if (cost is num)
              Text(
                formatRunCost(cost.toDouble()),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: BmoColors.textMuted,
                ),
              ),
            const Icon(Icons.chevron_right, size: 14, color: BmoColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: BmoColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: BmoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
