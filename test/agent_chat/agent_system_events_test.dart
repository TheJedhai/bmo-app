// Histórico com role "system" e parte {"type":"event"}: linha discreta
// centralizada, sem bolha; `ref: "run:N"` abre /coding/runs/N.
//
// Run:
//   flutter test test/agent_chat/agent_system_events_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_message_list.dart';
import 'package:bmo_app/features/agent_chat/widgets/agent_part_widgets.dart';
import 'package:bmo_app/features/agent_chat/widgets/chat_avatar.dart';
import 'package:bmo_app/features/agent_chat/widgets/speech_bubble.dart';

const _systemJson = {
  'id': 'sys-1',
  'role': 'system',
  'parts': [
    {
      'type': 'event',
      'text': 'run de coding #7 terminou',
      'source': 'coding',
      'ref': 'run:7',
    },
  ],
};

void main() {
  group('parse', () {
    test('role system + parte event', () {
      final message = AgentMessage.fromJson(_systemJson);
      expect(message.role, AgentRole.system);
      expect(message.isSystem, isTrue);
      final part = message.parts.single;
      expect(part, isA<AgentEventPart>());
      final event = part as AgentEventPart;
      expect(event.text, 'run de coding #7 terminou');
      expect(event.source, 'coding');
      expect(event.ref, 'run:7');
    });

    test('evento sem source/ref não quebra', () {
      final message = AgentMessage.fromJson({
        'id': 'sys-2',
        'role': 'system',
        'parts': [
          {'type': 'event', 'text': 'só o texto'},
        ],
      });
      final event = message.parts.single as AgentEventPart;
      expect(event.text, 'só o texto');
      expect(event.source, isNull);
      expect(event.ref, isNull);
    });

    test('role desconhecido continua assistente', () {
      final message = AgentMessage.fromJson({
        'id': 'm',
        'role': 'qualquer',
        'parts': [
          {'type': 'text', 'text': 'oi'},
        ],
      });
      expect(message.role, AgentRole.assistant);
    });

    test('locationOf converte ref de run', () {
      expect(AgentEventLine.locationOf('run:7'), '/coding/runs/7');
      expect(AgentEventLine.locationOf('run:x'), isNull);
      expect(AgentEventLine.locationOf('outra:coisa'), isNull);
      expect(AgentEventLine.locationOf(null), isNull);
    });
  });

  Widget listWidget(AgentMessage message) => MaterialApp(
        home: Scaffold(
          body: AgentMessageList(
            messages: [message],
            onApprove: (_) {},
            onDeny: (_, _) {},
          ),
        ),
      );

  testWidgets('renderiza linha centralizada, sem bolha nem avatar',
      (tester) async {
    await tester.pumpWidget(listWidget(AgentMessage.fromJson(_systemJson)));

    expect(find.text('run de coding #7 terminou'), findsOneWidget);
    expect(find.byType(SpeechBubble), findsNothing);
    expect(find.byType(ChatAvatar), findsNothing);
  });

  testWidgets('tocar no evento com ref run:N abre o run', (tester) async {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => Scaffold(
            body: AgentMessageList(
              messages: [AgentMessage.fromJson(_systemJson)],
              onApprove: (_) {},
              onDeny: (_, _) {},
            ),
          ),
        ),
        GoRoute(
          path: '/coding/runs/:runId',
          builder: (context, state) => Text(
            'run ${state.pathParameters['runId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('run de coding #7 terminou'));
    await tester.pumpAndSettle();

    expect(find.text('run 7'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/coding/runs/7');
  });

  testWidgets('evento sem ref não navega', (tester) async {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => Scaffold(
            body: AgentMessageList(
              messages: [
                AgentMessage.fromJson({
                  'id': 'sys-3',
                  'role': 'system',
                  'parts': [
                    {'type': 'event', 'text': 'sem destino'},
                  ],
                }),
              ],
              onApprove: (_) {},
              onDeny: (_, _) {},
            ),
          ),
        ),
        GoRoute(
          path: '/coding/runs/:runId',
          builder: (context, state) => const Text('run page'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('sem destino'));
    await tester.pumpAndSettle();

    expect(find.text('run page'), findsNothing);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/chat');
  });
}
