// Falha ao carregar mensagens: banner em pt-BR com ação de recarregar, sem
// vazar a mensagem em inglês do transporte ("An unexpected error occurred").
//
// Run:
//   flutter test test/agent_chat/agent_history_error_test.dart

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

class FailingHistoryClient extends AgentChatClient {
  FailingHistoryClient() : super(client: http.Client(), baseUrl: 'http://fake');

  bool failFetch = true;

  @override
  Future<AgentSession> ensureDailySession() async =>
      AgentSession.fromJson({'id': 'TODAY', 'title': 'hoje', 'kind': 'daily'});

  @override
  Future<List<AgentSession>> listSessions({
    int? projectId,
    String kind = 'chat',
  }) async => const [];

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    if (failFetch) throw Exception('An unexpected error occurred');
    return const [];
  }

  @override
  Future<void> markSessionRead(String sessionId) async {}

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {}

  @override
  Future<void> cancel(String sessionId) async {}
}

void main() {
  testWidgets('banner pt-BR com recarregar quando o histórico falha', (
    tester,
  ) async {
    final client = FailingHistoryClient();
    final events = StreamController<Map<String, dynamic>>.broadcast();
    final container = ProviderContainer(
      overrides: [
        agentChatClientProvider.overrideWithValue(client),
        agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
        eventsStreamProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await events.close();
    });
    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(selectedAgentSessionProvider(null).notifier).select('S1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: BmoTheme.themeData,
          home: const AgentChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não consegui carregar a conversa. Tentar de novo?'),
      findsOneWidget,
    );
    expect(find.textContaining('An unexpected error'), findsNothing);

    client.failFetch = false;
    await tester.tap(find.text('Recarregar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não consegui carregar a conversa. Tentar de novo?'),
      findsNothing,
    );
  });
}
