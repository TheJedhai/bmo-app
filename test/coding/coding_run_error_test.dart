// Motivo da falha de um run: contrato do modelo (servidor novo manda
// error_code/error_message, antigo não manda) e exibição no detalhe.
//
// Run:
//   flutter test test/coding/coding_run_error_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/features/coding/data/coding_run_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_run.dart';
import 'package:bmo_app/features/coding/presentation/coding_run_screen.dart';

class FakeEvents extends CodingRunEvents {
  @override
  Future<List<CodingRunEvent>> build(int runId) async => const [];
}

void main() {
  test('servidor antigo sem error_code/error_message vira null', () {
    final run = CodingRun.fromJson({
      'id': 1,
      'project_id': 2,
      'status': 'failed',
      'prompt': 'quebrou',
    });

    expect(run.errorCode, isNull);
    expect(run.errorMessage, isNull);
    expect(run.isFailure, isTrue);
  });

  test('error_code/error_message são lidos quando presentes', () {
    final run = CodingRun.fromJson({
      'id': 1,
      'project_id': 2,
      'status': 'timeout',
      'error_code': 'timeout',
      'error_message': 'passou de 30min',
    });

    expect(run.errorCode, 'timeout');
    expect(run.errorMessage, 'passou de 30min');
  });

  test('sucesso não é status de falha', () {
    const run = CodingRun(
      id: 1,
      projectId: 2,
      prompt: 'ok',
      status: CodingRunStatus.success,
    );
    expect(run.isFailure, isFalse);
  });

  testWidgets('detalhe do run mostra o error_message na falha',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/coding/runs/3',
      routes: [
        GoRoute(
          path: '/coding/runs/:runId',
          builder: (context, state) => CodingRunScreen(
            runId: int.parse(state.pathParameters['runId']!),
          ),
        ),
        GoRoute(path: '/coding', builder: (_, _) => const Text('coding')),
      ],
    );
    addTearDown(router.dispose);

    final run = CodingRun(
      id: 3,
      projectId: 1,
      prompt: 'roda os testes',
      status: CodingRunStatus.failed,
      errorCode: 'disk_full',
      errorMessage: 'sem espaço em disco',
    );
    final container = ProviderContainer(
      overrides: [
        codingRunProvider(3).overrideWith((ref) async => run),
        codingRunEventsProvider(3).overrideWith(FakeEvents.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('falha'), findsOneWidget);
    expect(find.text('erro'), findsOneWidget);
    expect(find.text('sem espaço em disco'), findsOneWidget);
  });
}
