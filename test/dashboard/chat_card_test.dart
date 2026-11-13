// Card de chat da dashboard: lista sessões do chat v2 e, ao tocar numa
// sessão, seleciona o id certo na feature agent_chat.
//
// Run:
//   flutter test test/dashboard/chat_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';
import 'package:bmo_app/features/dashboard/widgets/chat_card.dart';

class FakeAgentSessions extends AgentSessions {
  @override
  Future<List<AgentSession>> build() async => const [
        AgentSession(id: 'sess-2', title: 'Segunda conversa'),
        AgentSession(id: 'sess-1', title: 'Primeira conversa'),
      ];
}

void main() {
  testWidgets('lista as sessões e seleciona a tocada', (tester) async {
    final container = ProviderContainer(
      overrides: [agentSessionsProvider.overrideWith(FakeAgentSessions.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ChatCard(accent: Color(0xFFB8E0C2))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Segunda conversa'), findsOneWidget);
    expect(find.text('Primeira conversa'), findsOneWidget);

    await tester.tap(find.text('Primeira conversa'));
    await tester.pump();

    expect(container.read(selectedAgentSessionProvider), 'sess-1');
  });
}
