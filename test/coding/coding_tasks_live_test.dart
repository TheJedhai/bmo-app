// Tarefas do projeto e tentativas de passo ao vivo pelos eventos do
// /api/v1/stream: `coding.task.created/updated {patch}` e `coding.run.*
// {patch.step_id}`.
//
// Run:
//   flutter test test/coding/coding_tasks_live_test.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/coding_task_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_task.dart';

/// Patch completo como o servidor manda (`task_patch`, sem `steps`).
Map<String, dynamic> _patch(
  int id, {
  String status = 'executando',
  int currentStep = 1,
  int stepsDone = 0,
  String? lastEvent = 'início',
  double? cost,
  bool canJoin = false,
}) => {
  'task_id': id,
  'project_id': 1,
  'session_id': 'sess-1',
  'status': status,
  'objective': 'tarefa $id',
  'current_step': currentStep,
  'steps_total': 3,
  'steps_done': stepsDone,
  'cost_usd': cost,
  'duration_ms': null,
  'last_event': lastEvent,
  'error_code': null,
  'error_message': null,
  'branch': 'bmo/task-$id',
  'base_branch': 'main',
  'model': 'flash',
  'effort': 'medium',
  'joined_at': null,
  'approved_at': null,
  'started_at': null,
  'ended_at': null,
  'created_at': '2026-11-17T10:00:00Z',
  'can_join': canJoin,
};

CodingTask _task(int id, {String status = 'executando', int stepsDone = 0}) =>
    CodingTask.fromJson(_patch(id, status: status, stepsDone: stepsDone));

class FakeCodingClient extends CodingClient {
  FakeCodingClient() : super(client: http.Client(), baseUrl: 'http://fake');

  int getTaskCalls = 0;

  @override
  Future<List<CodingTask>> listTasks({int? projectId, int limit = 20}) async =>
      [_task(2), _task(1)];

  @override
  Future<CodingTask> getTask(int taskId) async {
    getTaskCalls++;
    return _task(taskId, stepsDone: 1);
  }
}

void main() {
  late FakeCodingClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = FakeCodingClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
    container = ProviderContainer(
      overrides: [
        codingClientProvider.overrideWithValue(client),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
    container.listen(codingTasksProvider(1), (_, _) {});
  });

  List<CodingTask> tasks() =>
      container.read(codingTasksProvider(1)).valueOrNull!;

  Future<void> settle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (container.read(codingTasksProvider(1)).valueOrNull == null) {
      if (DateTime.now().isAfter(deadline)) fail('timeout');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('coding.task.created entra no topo da lista', () async {
    await settle();
    expect(tasks().map((t) => t.taskId), [2, 1]);

    events.add({
      'type': 'coding.task.created',
      'patch': _patch(3, status: 'rascunho'),
    });
    await settle();

    expect(tasks().map((t) => t.taskId), [3, 2, 1]);
    expect(tasks().first.status, CodingTaskStatus.draft);
  });

  test('coding.task.updated substitui a tarefa pelo patch', () async {
    await settle();

    events.add({
      'type': 'coding.task.updated',
      'patch': _patch(
        2,
        status: 'pronta_para_juntar',
        currentStep: 3,
        stepsDone: 3,
        lastEvent: 'pronta',
        cost: 0.87,
        canJoin: true,
      ),
    });
    await settle();

    final task = tasks().firstWhere((t) => t.taskId == 2);
    expect(task.status, CodingTaskStatus.readyToJoin);
    expect(task.stepsDone, 3);
    expect(task.lastEvent, 'pronta');
    expect(task.costUsd, closeTo(0.87, 1e-9));
    expect(task.canJoin, isTrue);
    expect(task.branch, 'bmo/task-2');
  });

  test('evento de outro projeto é ignorado', () async {
    await settle();

    events.add({
      'type': 'coding.task.updated',
      'patch': {
        ..._patch(2),
        'project_id': 99,
        'last_event': 'de outro projeto',
      },
    });
    await settle();

    expect(tasks().firstWhere((t) => t.taskId == 2).lastEvent, 'início');
  });

  test('outros eventos não mexem na lista', () async {
    await settle();

    events.add({
      'type': 'rich.update',
      'block_id': 'coding-task-2',
      'patch': {'status': 'juntada'},
    });
    await settle();

    expect(tasks().firstWhere((t) => t.taskId == 2).status,
        CodingTaskStatus.running);
  });

  test('estado vivo da tarefa aplica patch e pede novo snapshot REST',
      () async {
    container.listen(codingTaskProvider(2), (_, _) {});
    container.listen(codingTaskLiveProvider(2), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final getsBefore = client.getTaskCalls;

    events.add({
      'type': 'coding.task.updated',
      'patch': _patch(2, status: 'bloqueada', lastEvent: 'passo falhou'),
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final live = container.read(codingTaskLiveProvider(2))!;
    expect(live['status'], 'bloqueada');
    expect(live['last_event'], 'passo falhou');
    expect(client.getTaskCalls, greaterThan(getsBefore),
        reason: 'passos só vêm do REST');
  });

  test('tentativas de um passo: coding.run.* com step_id', () async {
    container.listen(codingStepRunsProvider(5), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    events.add({
      'type': 'coding.run.created',
      'patch': {
        'run_id': 11,
        'step_id': 5,
        'project_id': 1,
        'status': 'running',
      },
    });
    events.add({
      'type': 'coding.run.created',
      'patch': {
        'run_id': 12,
        'step_id': 6,
        'project_id': 1,
        'status': 'running',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(codingStepRunsProvider(5)).keys.toList(), [11]);

    events.add({
      'type': 'coding.run.updated',
      'patch': {
        'run_id': 11,
        'step_id': 5,
        'status': 'failed',
        'cost_usd_computed': 0.12,
        'last_event': 'testes falharam',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final run = container.read(codingStepRunsProvider(5))[11]!;
    expect(run['status'], 'failed');
    expect(run['cost_usd_computed'], 0.12);
    expect(run['last_event'], 'testes falharam');
  });
}
