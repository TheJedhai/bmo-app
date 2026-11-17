import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bmo_app/core/navigation/app_router.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';

import '../../data/coding_providers.dart';
import '../../data/coding_task_providers.dart';
import '../../data/models/coding_task.dart';
import 'coding_task_look.dart';

/// Ações da tarefa: Juntar (só quando `can_join`), Cancelar (executando ou
/// aguardando aprovação), Retomar (bloqueada) e — no card — Detalhes.
///
/// Depois de cada POST aplica o estado devolvido no `codingTaskLive` e pede
/// um novo snapshot REST (os passos só vêm de lá).
class CodingTaskActions extends ConsumerStatefulWidget {
  final int taskId;
  final CodingTaskStatus status;
  final bool canJoin;

  /// Botão que abre `/coding/tasks/:id` (o card mostra; o detalhe não).
  final bool showDetail;

  const CodingTaskActions({
    super.key,
    required this.taskId,
    required this.status,
    required this.canJoin,
    this.showDetail = false,
  });

  @override
  ConsumerState<CodingTaskActions> createState() => _CodingTaskActionsState();
}

class _CodingTaskActionsState extends ConsumerState<CodingTaskActions> {
  bool _busy = false;
  String? _error;

  Future<void> _run(
    Future<CodingTask> Function() action, {
    required String failure,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final task = await action();
      ref.read(codingTaskLiveProvider(widget.taskId).notifier).applyStatus(task);
      ref.invalidate(codingTaskProvider(widget.taskId));
    } catch (e) {
      if (mounted) setState(() => _error = '$failure: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _merge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Juntar na base?'),
        content: const Text(
          'A branch da tarefa é juntada na branch base, sem push. '
          'Conflito bloqueia a tarefa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: const Color(0xFF0F1115),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Juntar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final client = ref.read(codingClientProvider);
    await _run(
      () => client.mergeTask(widget.taskId),
      failure: 'falha ao juntar',
    );
  }

  Future<void> _cancel() async {
    final client = ref.read(codingClientProvider);
    await _run(
      () => client.cancelTask(widget.taskId),
      failure: 'falha ao cancelar',
    );
  }

  Future<void> _resume() async {
    final client = ref.read(codingClientProvider);
    await _run(
      () => client.resumeTask(widget.taskId),
      failure: 'falha ao retomar',
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final canCancel = status == CodingTaskStatus.running ||
        status == CodingTaskStatus.awaitingApproval;
    final canResume = status == CodingTaskStatus.blocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.accentRed,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.canJoin)
              OutlinedButton(
                onPressed: _busy ? null : _merge,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmoColors.accentGreen,
                  side: BorderSide(
                    color: BmoColors.accentGreen.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Juntar'),
              ),
            if (canCancel)
              OutlinedButton(
                onPressed: _busy ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmoColors.accentRed,
                  side: BorderSide(
                    color: BmoColors.accentRed.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Cancelar'),
              ),
            if (canResume)
              OutlinedButton(
                onPressed: _busy ? null : _resume,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BmoColors.accentGreen,
                  side: BorderSide(
                    color: BmoColors.accentGreen.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Retomar'),
              ),
            if (widget.showDetail)
              TextButton(
                onPressed: () => appRouter.go('/coding/tasks/${widget.taskId}'),
                child: const Text('Detalhes'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Ícone + rótulo de status do passo (linha compacta do card e do detalhe).
class CodingStepStatusLine extends StatelessWidget {
  final CodingStepStatus status;

  const CodingStepStatusLine({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final look = codingStepLook(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(look.icon, size: 12, color: look.color),
        const SizedBox(width: 4),
        Text(
          look.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: look.color,
          ),
        ),
      ],
    );
  }
}
