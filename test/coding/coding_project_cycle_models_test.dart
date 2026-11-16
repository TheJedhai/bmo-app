// Modelos do ciclo de projeto: campos novos do run (custo real, last_event,
// parent, merge) e do projeto (base_branch, approval_mode, plano), incluindo
// o merge de `coding.run.updated`.
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

    test('mergePatch atualiza só o que veio', () {
      final run = CodingRun.fromJson(_runJson());
      final patched = run.mergePatch({
        'status': 'success',
        'last_event': 'pronto',
        'cost_usd_computed': 1.9,
        'merged_at': '2026-11-02T09:00:00Z',
      });

      expect(patched.status, CodingRunStatus.success);
      expect(patched.lastEvent, 'pronto');
      expect(patched.costUsdComputed, closeTo(1.9, 1e-9));
      expect(patched.isMerged, isTrue);
      // Campos não tocados pelo patch continuam.
      expect(patched.branch, 'bmo/run-7');
      expect(patched.parentRunId, 5);
      expect(patched.prompt, 'conserta o build');
    });
  });

  group('CodingProject', () {
    test('lê base_branch, approval_mode e plano', () {
      final project = CodingProject.fromJson({
        'id': 1,
        'name': 'BMO-APP',
        'primary_path': '/tmp/bmo-app',
        'permission_mode': 'acceptEdits',
        'allow_rules': ['ext: .py'],
        'deny_rules': ['path: secrets/'],
        'base_branch': 'main',
        'approval_mode': 'plan',
        'plan': {
          'text': 'migrar o grid',
          'max_runs': 5,
          'runs_used': 2,
          'max_cost_usd': 10.0,
          'cost_used': 3.5,
          'status': 'active',
        },
        'created_at': '2026-11-01T00:00:00Z',
        'updated_at': '2026-11-01T00:00:00Z',
      });

      expect(project.baseBranch, 'main');
      expect(project.approvalMode, 'plan');
      final plan = project.plan!;
      expect(plan.text, 'migrar o grid');
      expect(plan.runsLeft, 3);
      expect(plan.costLeft, closeTo(6.5, 1e-9));
      expect(plan.status, 'active');
    });

    test('projeto sem plano/defaults', () {
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
      expect(project.plan, isNull);
      expect(project.approvalMode, 'each_run');
      expect(project.baseBranch, isNull);
    });

    test('copyWith troca plano e approval_mode', () {
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
        approvalMode: 'plan',
        plan: const CodingPlan(text: 'novo', maxRuns: 1, status: 'active'),
      );
      expect(updated.approvalMode, 'plan');
      expect(updated.plan?.text, 'novo');
      expect(updated.name, 'x');
    });
  });
}
