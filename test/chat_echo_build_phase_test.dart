// activeChatEchoProvider não pode ser escrito durante a fase de build.
//
// Reentrar em /chat com uma conversa já selecionada monta a ChatScreen com
// selectedConversationIdProvider não-nulo. O listener que configura o eco
// roda com fireImmediately dentro do initState — ou seja, dentro do
// buildScope — e escrever provider ali estoura "Tried to modify a provider
// while the widget tree was building".
//
// Roda nas duas plataformas de propósito: o bug não é específico de iOS.
//
// Run:
//   flutter test test/chat_echo_build_phase_test.dart
//   flutter test --platform chrome test/chat_echo_build_phase_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/core/http/bmo_http_client.dart';
import 'package:bmo_app/core/http/client_factory.dart';
import 'package:bmo_app/core/identity/identity_state.dart';
import 'package:bmo_app/features/chat/chat_screen.dart';
import 'package:bmo_app/features/chat/providers/chat_providers.dart';
import 'package:bmo_app/features/coding/data/coding_providers.dart';
import 'package:bmo_app/features/coding/data/models/coding_session.dart';
import 'package:bmo_app/features/coding/presentation/coding_chat_screen.dart';

const _kProjectId = 7;
const _kSessionId = 'bmo-abc';

final _session = const CodingSession(
  id: 'uuid-1',
  sessionId: _kSessionId,
  projectId: _kProjectId,
  name: 'sessão',
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: null,
);

/// GET /api/chats devolve duas conversas; qualquer outra rota devolve `[]`
/// (histórico vazio basta — nada aqui exercita a rede de verdade).
String _mockBody(Uri url) {
  if (url.path.endsWith('/api/chats')) {
    return '[{"id":"conv-1","session_id":"sess-1","name":"um"},'
        '{"id":"conv-2","session_id":"sess-2","name":"dois"}]';
  }
  return '[]';
}

ProviderContainer _container({List<Override> extra = const []}) {
  return ProviderContainer(overrides: [
    httpClientProvider.overrideWith(
      (ref) => BmoHttpClient(
        MockClient((request) async => http.Response(
            _mockBody(request.url), 200,
            headers: {'content-type': 'application/json'})),
        () => '1',
      ),
    ),
    ...extra,
  ]);
}

void main() {
  testWidgets('montar ChatScreen com conversa já selecionada não escreve '
      'provider durante o build', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    // Estado de quem já entrou no chat antes: o id sobrevive à tela porque
    // selectedConversationIdProvider é global.
    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(selectedConversationIdProvider.notifier).state = 'conv-1';

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatScreen()),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('o eco fica configurado depois do primeiro frame',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(selectedConversationIdProvider.notifier).state = 'conv-1';

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatScreen()),
    ));
    await tester.pump();

    // É o callback que o BmoRichQuestionCard lê para ecoar a resposta na
    // conversa ativa — adiar a escrita não pode significar perdê-la.
    expect(container.read(activeChatEchoProvider), isNotNull);
  });

  testWidgets('trocar de conversa reaponta o eco', (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(selectedConversationIdProvider.notifier).state = 'conv-1';

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatScreen()),
    ));
    await tester.pump();
    final first = container.read(activeChatEchoProvider);

    container.read(selectedConversationIdProvider.notifier).state = 'conv-2';
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(container.read(activeChatEchoProvider), isNotNull);
    expect(identical(container.read(activeChatEchoProvider), first), isFalse);
  });

  testWidgets('o eco entrega na conversa selecionada, não na anterior',
      (tester) async {
    final container = _container();
    addTearDown(container.dispose);

    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(selectedConversationIdProvider.notifier).state = 'conv-1';

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatScreen()),
    ));
    await tester.pump();

    container.read(selectedConversationIdProvider.notifier).state = 'conv-2';
    await tester.pump();

    // É o caminho do BmoRichQuestionCard: lê o eco e chama.
    container.read(activeChatEchoProvider)!('resposta do card');
    await tester.pump();

    expect(
      container.read(chatControllerProvider('conv-2')).map((m) => m.text),
      contains('resposta do card'),
    );
    expect(container.read(chatControllerProvider('conv-1')), isEmpty);
  });

  // -------------------------------------------------------------------------
  // CodingChatScreen: mesma escrita, dois hooks diferentes
  // -------------------------------------------------------------------------

  /// `sessionsProvider` resolvido de forma síncrona — é o estado real de quem
  /// chegou pela tela de lista, e o que faz `whenData` rodar dentro do
  /// initState.
  ProviderContainer codingContainer() {
    final container = _container(extra: [
      sessionsProvider(_kProjectId).overrideWith((ref) => [_session]),
    ]);
    container.read(currentUserIdProvider.notifier).state = 1;
    container.read(enabledFeaturesProvider.notifier).state = const {'coding'};
    return container;
  }

  testWidgets('montar CodingChatScreen com sessões já carregadas não escreve '
      'provider durante o build', (tester) async {
    final container = codingContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CodingChatScreen(projectId: _kProjectId, sessionId: _kSessionId),
      ),
    ));

    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(container.read(activeChatEchoProvider), isNotNull);
  });

  testWidgets('desmontar CodingChatScreen limpa o eco sem escrever durante '
      'o build', (tester) async {
    final container = codingContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CodingChatScreen(projectId: _kProjectId, sessionId: _kSessionId),
      ),
    ));
    await tester.pump();
    expect(container.read(activeChatEchoProvider), isNotNull);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox()),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(container.read(activeChatEchoProvider), isNull);
  });

  testWidgets('desmontar não derruba o eco que outra tela já assumiu',
      (tester) async {
    final container = codingContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: CodingChatScreen(projectId: _kProjectId, sessionId: _kSessionId),
      ),
    ));
    await tester.pump();

    // Outra tela de chat assume o eco antes desta desmontar.
    void outroEco(String _) {}
    container.read(activeChatEchoProvider.notifier).state = outroEco;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SizedBox()),
    ));
    await tester.pump();

    expect(identical(container.read(activeChatEchoProvider), outroEco), isTrue);
  });
}
