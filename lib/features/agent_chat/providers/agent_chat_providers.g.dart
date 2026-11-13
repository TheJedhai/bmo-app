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
String _$agentSessionsHash() => r'97417223bf572a75e5e667fe4df150f824303a78';

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
String _$agentConversationHash() => r'b111d4afbb8d9415283ad5f1975e6ed1fbf93ee3';

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
