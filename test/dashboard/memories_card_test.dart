// Card de memórias da dashboard: contagem, duas prévias e chip de escopo.
//
// Run:
//   flutter test test/dashboard/memories_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/dashboard/widgets/memories_card.dart';
import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/data/memory_model.dart';
import 'package:bmo_app/features/memories/providers/memories_provider.dart';
import 'package:bmo_app/features/memories/widgets/memory_scope_chip.dart';

Memory _memory(int id, String content, {int? userId}) => Memory(
      id: id,
      content: content,
      source: 'agent',
      userId: userId,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

class FakeMemoriesClient extends MemoriesClient {
  FakeMemoriesClient(this.memories)
      : super(client: http.Client(), baseUrl: 'http://fake');

  final List<Memory> memories;

  @override
  Future<List<Memory>> list({
    MemoryScope? scope,
    String? source,
    int? limit,
    int? offset,
  }) async =>
      memories;
}

Widget _app(FakeMemoriesClient client) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 2),
      memoriesClientProvider.overrideWithValue(client),
    ],
    child: const MaterialApp(
      home: Scaffold(body: MemoriesCard(accent: Color(0xFF8FB8E8))),
    ),
  );
}

void main() {
  testWidgets('mostra contagem, prévias e escopo', (tester) async {
    await tester.pumpWidget(_app(FakeMemoriesClient([
      _memory(1, 'café sem açúcar', userId: 2),
      _memory(2, 'aniversário em março'),
      _memory(3, 'terceira não aparece'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('memórias'), findsOneWidget);
    expect(find.text('café sem açúcar'), findsOneWidget);
    expect(find.text('aniversário em março'), findsOneWidget);
    expect(find.text('terceira não aparece'), findsNothing);
    expect(find.widgetWithText(MemoryScopeChip, 'Pessoal'), findsOneWidget);
    expect(find.widgetWithText(MemoryScopeChip, 'Da casa'), findsOneWidget);
  });

  testWidgets('estado vazio', (tester) async {
    await tester.pumpWidget(_app(FakeMemoriesClient([])));
    await tester.pumpAndSettle();

    expect(find.text('nenhuma memória ainda'), findsOneWidget);
  });
}
