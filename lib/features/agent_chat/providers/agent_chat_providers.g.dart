// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$agentChatClientHash() => r'92b502af6c3aac2f767cdd895e8336203855ccad';

/// See also [agentChatClient].
@ProviderFor(agentChatClient)
final agentChatClientProvider = AutoDisposeProvider<AgentChatClient>.internal(
  agentChatClient,
  name: r'agentChatClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$agentChatClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AgentChatClientRef = AutoDisposeProviderRef<AgentChatClient>;
String _$agentChatPollIntervalHash() =>
    r'cb19c4b2e85f9d246a92b90edd2ca1efa97cb74b';

/// Intervalo de re-tentativa do `GET .../messages` quando o stream morre.
/// Os testes sobrescrevem com [Duration.zero].
///
/// Copied from [agentChatPollInterval].
@ProviderFor(agentChatPollInterval)
final agentChatPollIntervalProvider = AutoDisposeProvider<Duration>.internal(
  agentChatPollInterval,
  name: r'agentChatPollIntervalProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$agentChatPollIntervalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AgentChatPollIntervalRef = AutoDisposeProviderRef<Duration>;
String _$selectedAgentSessionHash() =>
    r'4360a558832c38ac9c21b8de3bced167eb3886b1';

/// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
/// `session_id: null`).
///
/// Depende da identidade de propósito: quando o usuário atual muda, o build
/// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
/// para outro.
///
/// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
/// dashboard, deep link), então não pode morrer por falta de listener.
///
/// Copied from [SelectedAgentSession].
@ProviderFor(SelectedAgentSession)
final selectedAgentSessionProvider =
    NotifierProvider<SelectedAgentSession, String?>.internal(
      SelectedAgentSession.new,
      name: r'selectedAgentSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedAgentSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedAgentSession = Notifier<String?>;
String _$agentSessionsHash() => r'19ae2402efe4cb80bd92fe13db0d92b6ce88fef9';

/// See also [AgentSessions].
@ProviderFor(AgentSessions)
final agentSessionsProvider =
    AutoDisposeAsyncNotifierProvider<
      AgentSessions,
      List<AgentSession>
    >.internal(
      AgentSessions.new,
      name: r'agentSessionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$agentSessionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AgentSessions = AutoDisposeAsyncNotifier<List<AgentSession>>;
String _$agentConversationHash() => r'2b383cb5ab8b43672b51d8b98fbbac0d8537c58a';

/// See also [AgentConversation].
@ProviderFor(AgentConversation)
final agentConversationProvider =
    AutoDisposeNotifierProvider<
      AgentConversation,
      AgentConversationState
    >.internal(
      AgentConversation.new,
      name: r'agentConversationProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$agentConversationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AgentConversation = AutoDisposeNotifier<AgentConversationState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
