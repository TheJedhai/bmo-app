import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_clamped_text.dart';

import '../../data/coding_task_providers.dart';
import '../../data/models/coding_run.dart';
import '../../data/models/coding_task.dart';
import 'coding_task_actions.dart';
import 'coding_task_look.dart';

/// Card do bloco rico `coding_task` (tarefa com passos).
///
/// O payload só traz `task_id` e o patch de `coding.task.*` não tem `steps`:
/// os números (status, passo, custo, `can_join`) vêm do [codingTaskLiveProvider]
/// e a lista de passos do REST ([codingTaskProvider]), re-sincronizado no
/// reconnect do SSE e a cada transição da tarefa.
class BmoRichCodingTaskCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichCodingTaskCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichCodingTaskCard> createState() =>
      _BmoRichCodingTaskCardState();
}

class _BmoRichCodingTaskCardState extends ConsumerState<BmoRichCodingTaskCard> {
  int get _taskId {
    final fromPayload = widget.block.payload['task_id'];
    if (fromPayload is int) return fromPayload;
    if (fromPayload is String) return int.tryParse(fromPayload) ?? 0;
    // Fallback pelo contrato do block_id: `coding-task-{task_id}`.
    return int.tryParse(widget.block.blockId.replaceFirst('coding-task-', '')) ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    final taskId = _taskId;
    if (taskId <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'tarefa de coding sem id',
          style: TextStyle(fontFamily: 'Inter', color: BmoColors.textMuted),
        ),
      );
    }

    final live = ref.watch(codingTaskLiveProvider(taskId));
    final snapshot = ref.watch(codingTaskProvider(taskId));

    // Re-sync em cada reconexão do SSE: o card pode ter perdido a transição.
    ref.listen<int>(sseGenerationProvider, (previous, next) {
      if (previous != next) ref.invalidate(codingTaskProvider(taskId));
    });

    final task = snapshot.valueOrNull;
    if (task == null && live == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: BmoColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.hasError ? 'tarefa indisponível' : 'carregando tarefa...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final rawStatus = live?['status'];
    final status = codingTaskStatusFrom(
      rawStatus is String ? rawStatus : task?.status.wire,
    );
    final look = codingTaskLook(status);
    final objective =
        live?['objective']?.toString() ?? task?.objective ?? '';
    final currentStep = _asInt(live?['current_step']) ?? task?.currentStep ?? 0;
    final stepsTotal = _asInt(live?['steps_total']) ?? task?.stepsTotal ?? 0;
    final stepsDone = _asInt(live?['steps_done']) ?? task?.stepsDone ?? 0;
    final cost = _asDouble(live?['cost_usd']) ?? task?.costUsd;
    final durationMs = _asInt(live?['duration_ms']) ?? task?.durationMs;
    final lastEvent = live?['last_event']?.toString() ?? task?.lastEvent;
    final errorMessage =
        live?['error_message']?.toString() ?? task?.errorMessage;
    final canJoin = (live?['can_join'] as bool?) ?? task?.canJoin ?? false;
    final steps = task?.steps ?? const <CodingTaskStep>[];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: look.color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CodingTaskStatusIcon(status: status),
                const SizedBox(width: 8),
                Text(
                  look.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: look.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (stepsTotal > 0)
                  Text(
                    '${formatStepProgress(currentStep, stepsTotal)} · '
                    '$stepsDone feito(s)',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
                  ),
              ],
            ),
            if (objective.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                objective,
                maxLines: 3,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.textPrimary),
              ),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final step in steps) _StepRow(step: step),
            ],
            if (lastEvent != null && lastEvent.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                lastEvent,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
              ),
            ],
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                errorMessage,
                maxLines: 3,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Meta(
                  icon: Icons.payments_outlined,
                  text: formatRunCost(cost),
                ),
                if (durationMs != null)
                  _Meta(
                    icon: Icons.timer_outlined,
                    text: formatRunDuration(durationMs),
                  ),
                if (task?.branch != null && task!.branch!.isNotEmpty)
                  _Meta(icon: Icons.call_split, text: task.branch!),
              ],
            ),
            const SizedBox(height: 8),
            CodingTaskActions(
              taskId: taskId,
              status: status,
              canJoin: canJoin,
              showDetail: true,
            ),
          ],
        ),
      ),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Linha compacta de um passo: sequência, título e status.
class _StepRow extends StatelessWidget {
  final CodingTaskStep step;

  const _StepRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final look = codingStepLook(step.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(look.icon, size: 12, color: look.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${step.seq}. ${step.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: step.status == CodingStepStatus.done
                    ? BmoColors.textMuted
                    : BmoColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            look.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: look.color,
            ),
          ),
        ],
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
        Icon(icon, size: 13, color: BmoColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
        ),
      ],
    );
  }
}
