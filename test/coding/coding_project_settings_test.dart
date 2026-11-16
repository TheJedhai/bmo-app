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
      find.text('Só o que estiver em allow roda; todo o resto é negado.'),
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
      find.text(
        'Edita arquivos sozinho; Bash e o resto só se estiverem em allow — '
        'o que não estiver é negado.',
      ),
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

    // Duas listas de regra, cada uma com um campo de texto. Campo vazio
    // desabilita o "adicionar".
    List<TextButton> addButtons() => tester
        .widgetList<TextButton>(find.widgetWithText(TextButton, 'adicionar'))
        .toList();
    expect(addButtons().every((b) => b.onPressed == null), isTrue);

    final allowField = find.byType(TextField).first;
    await tester.enterText(allowField, 'ext: .ts');
    await tester.pump();
    expect(addButtons().first.onPressed, isNotNull);

    await tester.tap(find.text('adicionar').first);
    await tester.pumpAndSettle();
    expect(find.text('ext: .ts'), findsOneWidget);
    // Campo limpo volta a desabilitar.
    expect(addButtons().first.onPressed, isNull);

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

  testWidgets('plano esgotado vira "último plano", sem botão de cancelar',
      (tester) async {
    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(
          text: 'x',
          maxRuns: 1,
          runsUsed: 1,
          status: 'exhausted',
        ),
      )),
    );

    expect(find.text('último plano: orçamento esgotado'), findsOneWidget);
    expect(find.text('Cancelar plano'), findsNothing);
  });

  testWidgets('plano cancelado mostra consumo congelado', (tester) async {
    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(
          text: 'plano antigo',
          maxRuns: 2,
          runsUsed: 1,
          maxCostUsd: 5,
          costUsed: 0.0421,
          status: 'cancelled',
          endedAt: null,
        ),
      )),
    );

    expect(find.text('último plano: cancelado'), findsOneWidget);
    expect(find.text('runs: 1 / 2'), findsOneWidget);
    expect(find.text('custo: US\$ 0.04 / US\$ 5.00'), findsOneWidget);
    expect(find.text('Cancelar plano'), findsNothing);
  });

  testWidgets('status desconhecido aparece cru', (tester) async {
    await _pump(
      tester,
      FakeCodingClient(_project(
        plan: const CodingPlan(text: 'y', status: 'paused'),
      )),
    );

    expect(find.text('último plano: paused'), findsOneWidget);
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

  testWidgets('Enter no campo também adiciona', (tester) async {
    final client = FakeCodingClient(_project());
    await _pump(tester, client);

    final allowField = find.byType(TextField).first;
    await tester.enterText(allowField, 'Bash(npm test:*)');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Bash(npm test:*)'), findsOneWidget);
  });

  testWidgets('campo vazio não adiciona nada', (tester) async {
    final client = FakeCodingClient(_project());
    await _pump(tester, client);

    final before = find.byTooltip('remover').evaluate().length;
    // Botão desabilitado: tocar não muda nada.
    await tester.tap(find.text('adicionar').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byTooltip('remover').evaluate().length, before);
    expect(find.text('nenhuma regra'), findsNothing);
  });

  testWidgets('allow e deny usam o próprio campo', (tester) async {
    final client = FakeCodingClient(_project());
    await _pump(tester, client);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Read(./secrets/**)');
    await tester.pumpAndSettle();
    await tester.tap(find.text('adicionar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // A regra entrou em deny, não em allow.
    expect(client.lastPatch?['deny_rules'], ['path: secrets/', 'Read(./secrets/**)']);
    expect(client.lastPatch?['allow_rules'], ['ext: .py']);
  });

  testWidgets('exemplos e ajuda das regras', (tester) async {
    await _pump(tester, FakeCodingClient(_project()));

    expect(find.text('Bash(npm test:*) ou Edit'), findsOneWidget);
    expect(find.text('Read(./secrets/**)'), findsOneWidget);
    expect(
      find.text('Ferramentas desta versão: Bash, Read e Edit (Write não existe).'),
      findsOneWidget,
    );
    expect(
      find.text('Deny bloqueia sem aviso, mesmo em bypassPermissions.'),
      findsOneWidget,
    );
  });

  testWidgets('base_branch nula explica que vem do próximo run',
      (tester) async {
    final project = CodingProject(
      id: 1,
      name: 'BMO-APP',
      primaryPath: '/tmp/bmo-app',
      extraPaths: const [],
      permissionMode: 'acceptEdits',
      allowRules: const [],
      denyRules: const [],
      createdAt: '',
      updatedAt: '',
    );
    await _pump(tester, FakeCodingClient(project));

    expect(
      find.text('definida no próximo run (branch atual do repositório)'),
      findsOneWidget,
    );
    expect(find.text('não informada'), findsNothing);
  });

  testWidgets('modos documentados têm descrição verificada', (tester) async {
    await _pump(tester, FakeCodingClient(_project(permissionMode: 'auto')));

    expect(find.text('Comportamento não verificado no servidor.'), findsOneWidget);
  });
}
