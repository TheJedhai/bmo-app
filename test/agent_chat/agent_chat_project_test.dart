// Chat v2 por projeto: lista e cria sessões com `project_id`, sem duplicar
// a tela. Cliente fake — nenhum teste toca a rede.
//
// Run:
//   flutter test test/agent_chat/agent_chat_project_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/agent_chat/data/agent_chat_client.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/agent_chat/data/agent_session.dart';
import 'package:bmo_app/features/agent_chat/providers/agent_chat_providers.dart';

class FakeAgentChatClient extends AgentChatClient {
  FakeAgentChatClient() : super(client: http.Client(), baseUrl: 'http://fake');

  final List<int?> listedProjects = [];
  final List<int?> sentProjects = [];

  @override
  Future<List<AgentSession>> listSessions({int? projectId}) async {
    listedProjects.add(projectId);
    return [
      AgentSession(
        id: projectId == null ? 'sess-main' : 'sess-p$projectId',
        title: projectId == null ? 'conversa principal' : 'conversa do projeto',
      ),
    ];
  }

  @override
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {
    sentProjects.add(projectId);
    yield TurnStarted(input: 'message', sessionId: 'sess-nova');
    yield const TextDelta('beleza');
    yield const TurnEnded(status: 'completed');
  }

  @override
  Future<List<AgentMessage>> fetchMessages(String sessionId) async => const [];
}

void main() {
  late FakeAgentChatClient client;
  late ProviderContainer container;

  setUp(() {
    client = FakeAgentChatClient();
    container = ProviderContainer(
      overrides: [
        agentChatClientProvider.overrideWithValue(client),
        agentChatPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentUserIdProvider.notifier).state = 1;
  });

  test('lista só as sessões do projeto (project_id na query, null sem)', () async {
    final doProjeto = await container.read(agentSessionsProvider(7).future);
    expect(doProjeto.single.id, 'sess-p7');

    final principal = await container.read(agentSessionsProvider(null).future);
    expect(principal.single.id, 'sess-main');

    expect(client.listedProjects, [7, null]);
  });

  test('primeiro envio de um projeto nasce com project_id', () async {
    container.listen(agentConversationProvider(7), (_, _) {});
    await pumpEventQueue();

    container.read(agentConversationProvider(7).notifier).send('oi');
    await pumpEventQueue();

    expect(client.sentProjects, [7]);
    final state = container.read(agentConversationProvider(7));
    expect(state.messages.last.plainText, 'beleza');
    // A sessão criada pelo servidor fica selecionada na família do projeto.
    expect(container.read(selectedAgentSessionProvider(7)), 'sess-nova');
    // A seleção do chat principal não é afetada.
    expect(container.read(selectedAgentSessionProvider(null)), isNull);
  });

  test('chat principal continua sem project_id', () async {
    container.listen(agentConversationProvider(null), (_, _) {});
    await pumpEventQueue();

    container.read(agentConversationProvider(null).notifier).send('oi');
    await pumpEventQueue();

    expect(client.sentProjects, [null]);
  });
}
