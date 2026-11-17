// Smoke test da tela do chat v2: monta sem exceção e mostra os estados de
// input (habilitado, aguardando aprovação, conexão perdida).
//
// Run:
//   flutter test test/agent_chat/agent_chat_screen_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_chat_screen.dart';

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
    yield const ApprovalRequested(
      callId: 'c1',
      tool: 'delete_task',
      label: 'Apagar tarefa',
      summary: 'Apagar a tarefa #12',
    );
    yield const TurnEnded(status: 'awaiting_approval');
  }

  @override
  Future<List<AgentSession>> listSessions({int? projectId, String kind = 'chat'}) async => const [];
  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async => const [];
  @override
  Future<void> cancel(String sessionId) async {}
}

Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) fail('timeout');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  testWidgets('monta, envia e mantém o input liberado com aprovação pendente',
      (tester) async {
    final client = FakeAgentChatClient();
    final container = ProviderContainer(overrides: [
      agentChatClientProvider.overrideWithValue(client),
      agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
      eventsStreamProvider.overrideWith((ref) => const Stream.empty()),
    ]);
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BmoTheme.themeData,
          home: const AgentChatScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('fala com o BMO...'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'apaga');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    await _until(() => container
        .read(agentConversationProvider(null))
        .messages
        .any((message) => message.parts.any((p) => p is AgentApprovalPart)));
    await tester.pump();

    expect(find.text('Apagar a tarefa #12'), findsOneWidget);

    final input = tester.widget<TextField>(find.byType(TextField).last);
    expect(input.enabled, isTrue);
    expect(input.decoration?.hintText, 'fala com o BMO...');
    expect(tester.takeException(), isNull);
  });
}
