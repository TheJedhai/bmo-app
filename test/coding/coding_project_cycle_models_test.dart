// Modelos do ciclo de projeto: campos novos do run (custo real, last_event,
// parent, merge) e do projeto (base_branch), incluindo o objeto do evento
// `coding.run.updated`.
//
// Run:
//   flutter test test/coding/coding_project_cycle_models_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';

Map<String, dynamic> _runJson() => {
      'id': 7,
      'project_id': 1,
      'prompt': 'conserta o build',
      'status': 'running',
      'branch': 'bmo/run-7',
      'cost_usd': 0.31,
      'last_event': 'Vou rodar os testes',
      'cost_usd_computed': 1.25,
      'session_id': 'sess-1',
      'parent_run_id': 5,
      'plan_id': 3,
      'usage': {'input_tokens': 1200, 'output_tokens': 340},
      'created_at': '2026-11-01T10:00:00Z',
    };

void main() {
  group('CodingRun', () {
    test('lê os campos do ciclo de projeto', () {
      final run = CodingRun.fromJson(_runJson());
      expect(run.lastEvent, 'Vou rodar os testes');
      expect(run.costUsdComputed, closeTo(1.25, 1e-9));
      expect(run.costUsd, closeTo(0.31, 1e-9));
      expect(run.sessionId, 'sess-1');
      expect(run.parentRunId, 5);
      expect(run.planId, 3);
      expect(run.usage?['input_tokens'], 1200);
      expect(run.isMerged, isFalse);
      expect(run.mergedAt, isNull);
    });

    test('cost_usd_computed nulo = custo não configurado', () {
      final run = CodingRun.fromJson({..._runJson(), 'cost_usd_computed': null});
      expect(run.costUsdComputed, isNull);
      expect(formatComputedCost(run.costUsdComputed), 'custo não configurado');
      expect(formatComputedCost(1.25), 'US\$ 1.25');
    });

    test('merged_at marca juntado na base', () {
      final run = CodingRun.fromJson({
        ..._runJson(),
        'status': 'success',
        'merged_at': '2026-11-02T09:00:00Z',
      });
      expect(run.isMerged, isTrue);
      expect(run.mergedAt?.day, 2);
    });

    test('aceita o objeto do evento (run_id + files_changed_count)', () {
      final run = CodingRun.fromJson({
        'run_id': 42,
        'project_id': 7,
        'session_id': 'e00c3dd7',
        'parent_run_id': null,
        'plan_id': 3,
        'merged_at': null,
        'status': 'running',
        'error_code': null,
        'error_message': null,
        'branch': null,
        'commit_sha': null,
        'files_changed_count': 4,
        'permission_denials_count': 2,
        'cost_usd': null,
        'cost_usd_computed': null,
        'duration_ms': 12345,
        'last_event': 'rodando testes',
      });

      expect(run.id, 42);
      expect(run.projectId, 7);
      expect(run.sessionId, 'e00c3dd7');
      expect(run.planId, 3);
      expect(run.filesChangedCount, 4);
      expect(run.lastEvent, 'rodando testes');
      expect(run.branch, isNull);
      expect(run.costUsdComputed, isNull);
    });

    test('usage por modelo fica cru no modelo', () {
      final run = CodingRun.fromJson({
        ..._runJson(),
        'usage': {
          'deepseek-v4-pro': {
            'inputTokens': 1782,
            'outputTokens': 1075,
            'cacheReadInputTokens': 1920,
            'cacheCreationInputTokens': 0,
          },
        },
      });
      final model = run.usage!['deepseek-v4-pro'] as Map;
      expect(model['inputTokens'], 1782);
      expect(model['cacheReadInputTokens'], 1920);
    });
  });

  group('CodingProject', () {
    test('lê base_branch e ignora campos removidos do contrato', () {
      final project = CodingProject.fromJson({
        'id': 1,
        'name': 'BMO-APP',
        'primary_path': '/tmp/bmo-app',
        'permission_mode': 'acceptEdits',
        'allow_rules': ['ext: .py'],
        'deny_rules': ['path: secrets/'],
        'base_branch': 'main',
        'created_at': '2026-11-01T00:00:00Z',
        'updated_at': '2026-11-01T00:00:00Z',
      });

      expect(project.baseBranch, 'main');
      expect(project.permissionMode, 'acceptEdits');
      expect(project.allowRules, ['ext: .py']);
      expect(project.denyRules, ['path: secrets/']);
    });

    test('projeto sem base_branch', () {
      final project = CodingProject.fromJson({
        'id': 2,
        'name': 'x',
        'primary_path': '/tmp/x',
        'permission_mode': 'manual',
        'allow_rules': [],
        'deny_rules': [],
        'created_at': '',
        'updated_at': '',
      });
      expect(project.baseBranch, isNull);
    });

    test('copyWith troca campos e mantém o resto', () {
      final project = CodingProject.fromJson({
        'id': 1,
        'name': 'x',
        'primary_path': '/tmp/x',
        'permission_mode': 'manual',
        'allow_rules': [],
        'deny_rules': [],
        'created_at': '',
        'updated_at': '',
      });
      final updated = project.copyWith(
        permissionMode: 'acceptEdits',
        baseBranch: 'main',
      );
      expect(updated.permissionMode, 'acceptEdits');
      expect(updated.baseBranch, 'main');
      expect(updated.name, 'x');
    });
  });
}
