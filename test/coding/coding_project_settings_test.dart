// Configurações do projeto: permission_mode com explicação, regras
// allow/deny editáveis, base_branch só leitura, approval_mode e plano ativo.
//
// Run:
//   flutter test test/coding/coding_project_settings_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/navigation/app_router.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/coding/data/coding_client.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_project.dart';
import 'package:bmo_app/features/coding/presentation/coding_project_settings_screen.dart';
import 'package:bmo_app/features/coding/presentation/widgets/permission_modes.dart';
import 'package:http/http.dart' as http;

CodingProject _project({
  String permissionMode = 'manual',
  String approvalMode = 'each_run',
  CodingPlan? plan,
}) =>
    CodingProject(
      id: 1,
      name: 'BMO-APP',
      primaryPath: '/tmp/bmo-app',
      extraPaths: const [],
      permissionMode: permissionMode,
      allowRules: const ['ext: .py'],
      denyRules: const ['path: secrets/'],
      baseBranch: 'main',
      approvalMode: approvalMode,
      plan: plan,
      createdAt: '',
      updatedAt: '',
    );

class FakeCodingClient extends CodingClient {
  FakeCodingClient(this.project)
      : super(client: http.Client(), baseUrl: 'http://fake');

  final CodingProject project;
  Map<String, dynamic>? lastPatch;
  int cancelCalls = 0;
  int cancelStatus = 204;

  @override
  Future<void> cancelPlan(int projectId) async {
    cancelCalls++;
    if (cancelStatus != 204) {
      throw CodingApiException(statusCode: cancelStatus, message: 'sem plano');
    }
  }

  @override
  Future<List<CodingProject>> listProjects() async => [project];

  @override
  Future<CodingProject> updateProject(int id, Map<String, dynamic> data) async {
    lastPatch = data;
    return project.copyWith(
      permissionMode: data['permission_mode'] as String?,
      allowRules: (data['allow_rules'] as List?)?.cast<String>(),
      denyRules: (data['deny_rules'] as List?)?.cast<String>(),
    );
  }
}

Future<void> _pump(WidgetTester tester, FakeCodingClient client) async {
  // Tela alta: a lista de config é longa e o teste não deve depender de scroll.
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(client));
  await tester.pumpAndSettle();
}

Widget _app(FakeCodingClient client) => ProviderScope(
      overrides: [
        enabledFeaturesProvider.overrideWith((ref) => {'coding'}),
        currentUserIdProvider.overrideWith((ref) => 1),
        codingClientProvider.overrideWithValue(client),
      ],
      child: MaterialApp(
        theme: BmoTheme.themeData,
        home: const CodingProjectSettingsScreen(projectId: 1),
      ),
    );

void main() {
  testWidgets('mostra modo com descrição, regras, base e aprovação',
      (tester) async {
    await _pump(tester, FakeCodingClient(_project()));

    expect(find.text('Manual'), findsOneWidget);
    expect(
      find.text('Pede aprovação para cada ação do agente.'),
      findsOneWidget,
    );
    expect(find.text('ext: .py'), findsOneWidget);
    expect(find.text('path: secrets/'), findsOneWidget);
    expect(find.text('main'), findsOneWidget);
    expect(find.text('Aprovar cada run'), findsOneWidget);
    expect(find.text('sem plano ativo'), findsOneWidget);
  });

  testWidgets('troca o modo e salva o patch', (tester) async {
    final client = FakeCodingClient(_project());
    await _pump(tester, client);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceitar edições').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Edita arquivos sozinho; pede aprovação para o resto.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(client.lastPatch?['permission_mode'], 'acceptEdits');
    expect(client.lastPatch?['approval_mode'], 'each_run');
    expect(client.lastPatch?['allow_rules'], ['ext: .py']);
  });

  testWidgets('adiciona e remove regra', (tester) async {
    final client = FakeCodingClient(_project());
    await _pump(tester, client);

    // Duas listas de regra, cada uma com um campo de texto.
    final allowField = find.byType(TextField).first;
    await tester.enterText(allowField, 'ext: .ts');
    await tester.tap(find.text('adicionar').first);
    await tester.pumpAndSettle();
    expect(find.text('ext: .ts'), findsOneWidget);

    // Remove a regra original (primeiro X da lista allow).
    await tester.tap(find.byTooltip('remover').first);
    await tester.pumpAndSettle();
    expect(find.text('ext: .py'), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(client.lastPatch?['allow_rules'], ['ext: .ts']);
  });

  testWidgets('plano ativo mostra consumo de runs e custo', (tester) async {
    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(
          text: 'migrar o grid',
          maxRuns: 5,
          runsUsed: 2,
          maxCostUsd: 10,
          costUsed: 3.5,
          status: 'active',
        ),
      )),
    );

    expect(find.text('migrar o grid'), findsOneWidget);
    expect(find.text('runs: 2 / 5'), findsOneWidget);
    expect(find.text('custo: US\$ 3.50 / US\$ 10.00'), findsOneWidget);
    expect(find.text('status: ativo'), findsOneWidget);
    // Rota POST /coding/projects/{id}/plan/cancel: botão disponível.
    expect(find.text('Cancelar plano'), findsOneWidget);
  });

  testWidgets('modo legado aparece marcado como legado', (tester) async {
    await _pump(tester, FakeCodingClient(_project(permissionMode: 'allow_all')));

    expect(find.text('allow_all (legado)'), findsOneWidget);
    expect(permissionModeLabel('allow_all'), 'allow_all');
    expect(permissionModeLabel('plan'), 'Planejar');
  });

  test('rota /coding/:projectId/settings existe', () {
    final paths = [
      for (final route in appRoutes)
        if (route is GoRoute) route.path,
    ];
    expect(paths, contains('/coding/:projectId/settings'));
  });

  testWidgets('status do plano: exhausted e desconhecido', (tester) async {
    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(text: 'x', maxRuns: 1, runsUsed: 1, status: 'exhausted'),
      )),
    );
    expect(find.text('status: orçamento esgotado'), findsOneWidget);

    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(text: 'y', status: 'paused'),
      )),
    );
    expect(find.text('status: paused'), findsOneWidget);
  });

  testWidgets('cancelar plano pede confirmação, chama o POST e limpa o plano',
      (tester) async {
    final client = FakeCodingClient(_project(
      plan: const CodingPlan(text: 'migrar o grid', maxRuns: 5, status: 'active'),
    ));
    await _pump(tester, client);

    // O botão fica dentro do cartão do plano; abre confirmação.
    await tester.tap(find.text('Cancelar plano'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar plano?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar plano'));
    await tester.pumpAndSettle();

    expect(client.cancelCalls, 1);
    expect(find.text('sem plano ativo'), findsOneWidget);
    expect(find.text('migrar o grid'), findsNothing);
  });

  testWidgets('cancelar sem plano ativo mostra 409 amigável', (tester) async {
    final client = FakeCodingClient(_project(
      plan: const CodingPlan(text: 'migrar', status: 'active'),
    ))
      ..cancelStatus = 409;
    await _pump(tester, client);

    await tester.tap(find.text('Cancelar plano'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar plano'));
    await tester.pumpAndSettle();

    expect(find.text('não há plano ativo'), findsOneWidget);
    // O plano continua na tela (o servidor não confirmou o cancelamento).
    expect(find.text('migrar'), findsOneWidget);
  });
}
