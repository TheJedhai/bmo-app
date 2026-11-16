// Tela de memórias: lista, filtro de escopo, busca no servidor, criar/editar
// com escopo e apagar. Cliente fake — sem rede.
//
// Run:
//   flutter test test/memories/memories_screen_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/data/memory_model.dart';
import 'package:bmo_app/features/memories/presentation/memories_screen.dart';
import 'package:bmo_app/features/memories/providers/memories_provider.dart';
import 'package:bmo_app/features/memories/widgets/memory_scope_chip.dart';

Memory _memory(int id, String content, {int? userId}) => Memory(
      id: id,
      content: content,
      source: 'manual',
      userId: userId,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

class FakeMemoriesClient extends MemoriesClient {
  FakeMemoriesClient() : super(client: http.Client(), baseUrl: 'http://fake');

  List<Memory> memories = [
    _memory(1, 'café sem açúcar', userId: 2),
    _memory(2, 'aniversário do casal é em março'),
  ];

  final List<MemoryScope?> listedScopes = [];
  final List<String> searched = [];
  final List<bool> createdPersonal = [];
  final List<(int, String?, bool?)> updated = [];
  final List<int> deleted = [];

  @override
  Future<List<Memory>> list({
    MemoryScope? scope,
    String? source,
    int? limit,
    int? offset,
  }) async {
    listedScopes.add(scope);
    return memories.where((m) {
      return switch (scope) {
        MemoryScope.personal => m.isPersonal,
        MemoryScope.house => !m.isPersonal,
        _ => true,
      };
    }).toList();
  }

  @override
  Future<List<Memory>> search({
    required String query,
    MemoryScope? scope,
    int? limit,
  }) async {
    searched.add(query);
    return memories
        .where((m) => m.content.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  Future<Memory> create(String content, {bool personal = false}) async {
    createdPersonal.add(personal);
    final memory = _memory(99, content, userId: personal ? 2 : null);
    memories = [memory, ...memories];
    return memory;
  }

  @override
  Future<Memory> update(int id, {String? content, bool? personal}) async {
    updated.add((id, content, personal));
    return _memory(id, content ?? '', userId: personal == false ? null : 2);
  }

  @override
  Future<void> delete(int id) async {
    deleted.add(id);
    memories = memories.where((m) => m.id != id).toList();
  }
}

Widget _app(FakeMemoriesClient client) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 2),
      memoriesClientProvider.overrideWithValue(client),
    ],
    child: const MaterialApp(home: MemoriesScreen()),
  );
}

void main() {
  testWidgets('lista memórias com chip de escopo', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.text('café sem açúcar'), findsOneWidget);
    expect(find.text('aniversário do casal é em março'), findsOneWidget);
    expect(find.widgetWithText(MemoryScopeChip, 'Pessoal'), findsOneWidget);
    expect(find.widgetWithText(MemoryScopeChip, 'Da casa'), findsOneWidget);
    expect(client.listedScopes, [MemoryScope.all]);
  });

  testWidgets('filtro de escopo refaz a listagem', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pessoal'));
    await tester.pumpAndSettle();

    expect(client.listedScopes.last, MemoryScope.personal);
    expect(find.text('café sem açúcar'), findsOneWidget);
    expect(find.text('aniversário do casal é em março'), findsNothing);
  });

  testWidgets('busca vai ao servidor com debounce', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'café');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(client.searched, ['café']);
    expect(find.text('café sem açúcar'), findsOneWidget);
    expect(find.text('aniversário do casal é em março'), findsNothing);
  });

  testWidgets('cria memória com escopo pessoal', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    // Escopo de criação: "Pessoal" no toggle de criação (o primeiro).
    await tester.tap(
      find.descendant(
        of: find.byType(MemoryScopeToggle).first,
        matching: find.text('Pessoal'),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'gosta de azul');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(client.createdPersonal, [true]);
    expect(find.text('gosta de azul'), findsOneWidget);
  });

  testWidgets('edita conteúdo e escopo', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('café sem açúcar'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'café sem açúcar'),
      'café com açúcar',
    );
    // Toggle do item em edição (o de criação fica acima na árvore).
    await tester.tap(
      find.descendant(
        of: find.byType(MemoryScopeToggle).last,
        matching: find.text('Da casa'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Salvar'));
    await tester.pumpAndSettle();

    expect(client.updated.single, (1, 'café com açúcar', false));
  });

  testWidgets('apaga após confirmação', (tester) async {
    final client = FakeMemoriesClient();
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    expect(client.deleted, [1]);
    expect(find.text('café sem açúcar'), findsNothing);
  });
}
