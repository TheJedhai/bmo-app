import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/events/events_provider.dart';
import '../../../core/identity/identity_state.dart';
import 'coding_providers.dart';
import 'models/coding_task.dart';

part 'coding_task_providers.g.dart';

/// Quantas tarefas a lista do projeto pede ao servidor (1..50).
const int kCodingTasksLimit = 20;

/// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
/// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
/// O `patch` é o objeto completo do card (sem `steps`).
@riverpod
class CodingTasks extends _$CodingTasks {
  @override
  Future<List<CodingTask>> build(int projectId) async {
    final userId = ref.watch(currentUserIdProvider);

    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _applyLive(event);
    });

    if (userId == null) return const [];
    final client = ref.watch(codingClientProvider);
    return client.listTasks(projectId: projectId, limit: kCodingTasksLimit);
  }

  void _applyLive(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'coding.task.created' && type != 'coding.task.updated') return;

    final current = state.valueOrNull;
    if (current == null) return;

    final patch = event['patch'];
    if (patch is! Map) return;
    final task = CodingTask.fromJson(Map<String, dynamic>.from(patch));
    if (task.taskId <= 0 || task.projectId != projectId) return;

    if (type == 'coding.task.created') {
      state = AsyncData([
        task,
        for (final existing in current)
          if (existing.taskId != task.taskId) existing,
      ]);
      return;
    }

    var changed = false;
    final next = <CodingTask>[];
    for (final existing in current) {
      if (existing.taskId == task.taskId) {
        changed = true;
        next.add(task);
      } else {
        next.add(existing);
      }
    }
    if (changed) state = AsyncData(next);
  }
}

/// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
/// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
/// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
@Riverpod(keepAlive: true)
class CodingTaskLive extends _$CodingTaskLive {
  @override
  Map<String, dynamic>? build(int taskId) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _applyEvent(event);
    });
    return null;
  }

  void _applyEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'coding.task.created' || type == 'coding.task.updated') {
      final patch = event['patch'];
      if (patch is! Map) return;
      final map = Map<String, dynamic>.from(patch);
      final rawId = map['task_id'] ?? map['id'];
      final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId');
      if (id != taskId) return;
      state = {...?state, ...map};
      // Os passos só existem no REST: cada transição de tarefa pede um novo
      // snapshot. Inativo (card desmontado) é no-op.
      ref.invalidate(codingTaskProvider(taskId));
      return;
    }
    if (type == 'rich.update' && event['block_id'] == 'coding-task-$taskId') {
      final patch = event['patch'];
      if (patch is Map) {
        state = {...?state, ...Map<String, dynamic>.from(patch)};
      }
    }
  }

  /// Aplica localmente o estado devolvido por cancel/resume/merge, sem
  /// esperar o SSE (que confirma depois).
  void applyStatus(CodingTask task) {
    state = {
      ...?state,
      'task_id': task.taskId,
      'project_id': task.projectId,
      'status': task.status.wire,
      'steps_total': task.stepsTotal,
      'steps_done': task.stepsDone,
      'current_step': task.currentStep,
      'cost_usd': task.costUsd,
      'duration_ms': task.durationMs,
      'last_event': task.lastEvent,
      'error_message': task.errorMessage,
      'can_join': task.canJoin,
    };
  }
}

/// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
/// pelo detalhe, re-sincronizado no reconnect do SSE.
@riverpod
Future<CodingTask> codingTask(CodingTaskRef ref, int taskId) async {
  final client = ref.watch(codingClientProvider);
  return client.getTask(taskId);
}

/// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
///
/// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
/// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
/// uma lista paginada (`GET /coding/runs?step_id=`).
@Riverpod(keepAlive: true)
class CodingStepRuns extends _$CodingStepRuns {
  @override
  Map<int, Map<String, dynamic>> build(int stepId) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event != null) _applyEvent(event);
    });
    return const {};
  }

  void _applyEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'coding.run.created' && type != 'coding.run.updated') return;

    final patch = event['patch'];
    if (patch is! Map) return;
    final map = Map<String, dynamic>.from(patch);
    final rawStep = map['step_id'];
    final step = rawStep is num ? rawStep.toInt() : int.tryParse('$rawStep');
    if (step != stepId) return;

    final rawRun = map['run_id'] ?? map['id'];
    final runId = rawRun is num ? rawRun.toInt() : int.tryParse('$rawRun');
    if (runId == null || runId <= 0) return;

    state = {
      ...state,
      runId: {...?state[runId], ...map},
    };
  }
}
