// Botão "Memórias" no topo do chat abre o modal, nas duas telas de chat
// (principal e de projeto). Fakes — sem rede.
//
// Run:
//   flutter test test/agent_chat/agent_chat_memories_button_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_chat_screen.dart';
import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/data/memory_model.dart';
import 'package:bmo_app/features/memories/providers/memories_provider.dart';

class FakeAgentChatClient extends AgentChatClient {
  FakeAgentChatClient() : super(client: http.Client(), baseUrl: 'http://fake');

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {
    yield const TurnStarted(input: 'message', sessionId: 'sess-1');
    yield const TurnEnded(status: 'completed');
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId}) async => const [];
  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async => const [];
  @override
  Future<void> cancel(String sessionId) async {}
}

class FakeMemoriesClient extends MemoriesClient {
  FakeMemoriesClient() : super(client: http.Client(), baseUrl: 'http://fake');

  @override
  Future<List<Memory>> list({
    MemoryScope? scope,
    String? source,
    int? limit,
    int? offset,
  }) async =>
      [
        Memory(
          id: 1,
          content: 'café sem açúcar',
          source: 'manual',
          userId: 1,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 2),
        ),
      ];
}

Future<void> _pumpChat(WidgetTester tester, {int? projectId}) async {
  final container = ProviderContainer(
    overrides: [
      agentChatClientProvider.overrideWithValue(FakeAgentChatClient()),
      agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
      memoriesClientProvider.overrideWithValue(FakeMemoriesClient()),
    ],
  );
  addTearDown(container.dispose);
  container.read(currentUserIdProvider.notifier).state = 1;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: BmoTheme.themeData,
        home: AgentChatScreen(projectId: projectId),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('chat principal: botão Memórias abre o modal', (tester) async {
    await _pumpChat(tester);

    expect(find.text('Memórias'), findsNothing);

    await tester.tap(find.byTooltip('Memórias'));
    await tester.pumpAndSettle();

    expect(find.text('Nova memória...'), findsOneWidget);
    expect(find.text('café sem açúcar'), findsOneWidget);
  });

  testWidgets('chat de projeto: botão Memórias abre o modal', (tester) async {
    await _pumpChat(tester, projectId: 1);

    await tester.tap(find.byTooltip('Memórias'));
    await tester.pumpAndSettle();

    expect(find.text('Nova memória...'), findsOneWidget);
  });

  testWidgets('modal fecha no X', (tester) async {
    await _pumpChat(tester);

    await tester.tap(find.byTooltip('Memórias'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Nova memória...'), findsNothing);
  });
}
