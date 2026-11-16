// Card rico `memory_saved`: desfazer via DELETE, patches de rich.update
// (undone/content), re-sync por REST no mount/reconnect (404 = desfeita).
//
// Run:
//   flutter test test/memories/memory_rich_card_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/data/memory_model.dart';
import 'package:bmo_app/features/memories/providers/memories_provider.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_rich_memory_card.dart';

const _block = BmoRichBlock(
  v: 2,
  type: 'memory_saved',
  blockId: 'memory-5',
  payload: {'memory_id': 5, 'content': 'gosta de café', 'scope': 'personal'},
  mutable: true,
);

Memory _memory({int id = 5, String content = 'gosta de café', int? userId = 2}) =>
    Memory(
      id: id,
      content: content,
      source: 'agent',
      userId: userId,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
    );

class FakeMemoriesClient extends MemoriesClient {
  FakeMemoriesClient() : super(client: http.Client(), baseUrl: 'http://fake');

  /// null = 404 (memória desfeita).
  Memory? memory = _memory();

  int getCalls = 0;
  final List<int> deleted = [];

  @override
  Future<Memory> get(int id) async {
    getCalls++;
    final m = memory;
    if (m == null) {
      throw MemoriesApiException(
        statusCode: 404,
        errorCode: 'memory_not_found',
        message: 'Memory $id not found',
      );
    }
    return m;
  }

  @override
  Future<void> delete(int id) async {
    deleted.add(id);
    memory = null;
  }
}

void main() {
  late FakeMemoriesClient client;
  late StreamController<Map<String, dynamic>> events;
  late ProviderContainer container;

  setUp(() {
    client = FakeMemoriesClient();
    events = StreamController<Map<String, dynamic>>.broadcast();
  });

  tearDown(() {
    container.dispose();
    events.close();
  });

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        memoriesClientProvider.overrideWithValue(client),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BmoRichMemoryCard(block: _block),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra conteúdo, escopo e Desfazer', (tester) async {
    await pump(tester);

    expect(find.text('Memória salva'), findsOneWidget);
    expect(find.text('gosta de café'), findsOneWidget);
    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text('Desfazer'), findsOneWidget);
    expect(client.getCalls, 1);
  });

  testWidgets('Desfazer chama DELETE e esconde o botão', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(client.deleted, [5]);
    expect(find.text('Desfeita'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
  });

  testWidgets('patch {status: undone} marca desfeita', (tester) async {
    await pump(tester);

    events.add({
      'type': 'rich.update',
      'block_id': 'memory-5',
      'patch': {'status': 'undone'},
    });
    await tester.pumpAndSettle();

    expect(find.text('Desfeita'), findsOneWidget);
    expect(find.text('Desfazer'), findsNothing);
  });

  testWidgets('patch {content} atualiza o texto', (tester) async {
    await pump(tester);

    events.add({
      'type': 'rich.update',
      'block_id': 'memory-5',
      'patch': {'content': 'gosta de chá'},
    });
    await tester.pumpAndSettle();

    expect(find.text('gosta de chá'), findsOneWidget);
    expect(find.text('gosta de café'), findsNothing);
  });

  testWidgets('patch de outro block_id não mexe', (tester) async {
    await pump(tester);

    events.add({
      'type': 'rich.update',
      'block_id': 'memory-99',
      'patch': {'status': 'undone'},
    });
    await tester.pumpAndSettle();

    expect(find.text('Memória salva'), findsOneWidget);
    expect(find.text('Desfazer'), findsOneWidget);
  });

  testWidgets('404 no re-sync do reconnect = desfeita', (tester) async {
    await pump(tester);
    expect(find.text('Memória salva'), findsOneWidget);

    client.memory = null;
    container.read(sseGenerationProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Desfeita'), findsOneWidget);
  });

  testWidgets('re-sync atualiza conteúdo vindo do REST', (tester) async {
    await pump(tester);

    client.memory = _memory(content: 'gosta de café forte', userId: null);
    container.read(sseGenerationProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('gosta de café forte'), findsOneWidget);
    expect(find.text('Da casa'), findsOneWidget);
  });
}
