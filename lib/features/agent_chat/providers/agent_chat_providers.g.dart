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
    r'c7a2528ad440a655974e68f137e3f9498e7906ce';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$SelectedAgentSession extends BuildlessNotifier<String?> {
  late final int? projectId;

  String? build(int? projectId);
}

/// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
/// `session_id: null`).
///
/// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
/// Cada projeto tem a sua própria seleção.
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
const selectedAgentSessionProvider = SelectedAgentSessionFamily();

/// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
/// `session_id: null`).
///
/// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
/// Cada projeto tem a sua própria seleção.
///
/// Depende da identidade de propósito: quando o usuário atual muda, o build
/// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
/// para outro.
///
/// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
/// dashboard, deep link), então não pode morrer por falta de listener.
///
/// Copied from [SelectedAgentSession].
class SelectedAgentSessionFamily extends Family<String?> {
  /// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
  /// `session_id: null`).
  ///
  /// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
  /// Cada projeto tem a sua própria seleção.
  ///
  /// Depende da identidade de propósito: quando o usuário atual muda, o build
  /// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
  /// para outro.
  ///
  /// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
  /// dashboard, deep link), então não pode morrer por falta de listener.
  ///
  /// Copied from [SelectedAgentSession].
  const SelectedAgentSessionFamily();

  /// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
  /// `session_id: null`).
  ///
  /// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
  /// Cada projeto tem a sua própria seleção.
  ///
  /// Depende da identidade de propósito: quando o usuário atual muda, o build
  /// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
  /// para outro.
  ///
  /// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
  /// dashboard, deep link), então não pode morrer por falta de listener.
  ///
  /// Copied from [SelectedAgentSession].
  SelectedAgentSessionProvider call(int? projectId) {
    return SelectedAgentSessionProvider(projectId);
  }

  @override
  SelectedAgentSessionProvider getProviderOverride(
    covariant SelectedAgentSessionProvider provider,
  ) {
    return call(provider.projectId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'selectedAgentSessionProvider';
}

/// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
/// `session_id: null`).
///
/// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
/// Cada projeto tem a sua própria seleção.
///
/// Depende da identidade de propósito: quando o usuário atual muda, o build
/// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
/// para outro.
///
/// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
/// dashboard, deep link), então não pode morrer por falta de listener.
///
/// Copied from [SelectedAgentSession].
class SelectedAgentSessionProvider
    extends NotifierProviderImpl<SelectedAgentSession, String?> {
  /// Sessão aberta na tela. `null` = conversa nova (primeiro envio vai com
  /// `session_id: null`).
  ///
  /// A chave é o projeto: `null` = chat principal; `N` = conversas do projeto.
  /// Cada projeto tem a sua própria seleção.
  ///
  /// Depende da identidade de propósito: quando o usuário atual muda, o build
  /// roda de novo e a seleção volta a `null` — sessão de um perfil nunca vaza
  /// para outro.
  ///
  /// `keepAlive`: a seleção é gravada antes de a tela do chat existir (card da
  /// dashboard, deep link), então não pode morrer por falta de listener.
  ///
  /// Copied from [SelectedAgentSession].
  SelectedAgentSessionProvider(int? projectId)
    : this._internal(
        () => SelectedAgentSession()..projectId = projectId,
        from: selectedAgentSessionProvider,
        name: r'selectedAgentSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$selectedAgentSessionHash,
        dependencies: SelectedAgentSessionFamily._dependencies,
        allTransitiveDependencies:
            SelectedAgentSessionFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  SelectedAgentSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectId,
  }) : super.internal();

  final int? projectId;

  @override
  String? runNotifierBuild(covariant SelectedAgentSession notifier) {
    return notifier.build(projectId);
  }

  @override
  Override overrideWith(SelectedAgentSession Function() create) {
    return ProviderOverride(
      origin: this,
      override: SelectedAgentSessionProvider._internal(
        () => create()..projectId = projectId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        projectId: projectId,
      ),
    );
  }

  @override
  NotifierProviderElement<SelectedAgentSession, String?> createElement() {
    return _SelectedAgentSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedAgentSessionProvider &&
        other.projectId == projectId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, projectId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SelectedAgentSessionRef on NotifierProviderRef<String?> {
  /// The parameter `projectId` of this provider.
  int? get projectId;
}

class _SelectedAgentSessionProviderElement
    extends NotifierProviderElement<SelectedAgentSession, String?>
    with SelectedAgentSessionRef {
  _SelectedAgentSessionProviderElement(super.provider);

  @override
  int? get projectId => (origin as SelectedAgentSessionProvider).projectId;
}

String _$agentSessionsHash() => r'519cd4e54360e843583ec91948c3e55077a43798';

abstract class _$AgentSessions
    extends BuildlessAutoDisposeAsyncNotifier<List<AgentSession>> {
  late final int? projectId;

  FutureOr<List<AgentSession>> build(int? projectId);
}

/// See also [AgentSessions].
@ProviderFor(AgentSessions)
const agentSessionsProvider = AgentSessionsFamily();

/// See also [AgentSessions].
class AgentSessionsFamily extends Family<AsyncValue<List<AgentSession>>> {
  /// See also [AgentSessions].
  const AgentSessionsFamily();

  /// See also [AgentSessions].
  AgentSessionsProvider call(int? projectId) {
    return AgentSessionsProvider(projectId);
  }

  @override
  AgentSessionsProvider getProviderOverride(
    covariant AgentSessionsProvider provider,
  ) {
    return call(provider.projectId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'agentSessionsProvider';
}

/// See also [AgentSessions].
class AgentSessionsProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          AgentSessions,
          List<AgentSession>
        > {
  /// See also [AgentSessions].
  AgentSessionsProvider(int? projectId)
    : this._internal(
        () => AgentSessions()..projectId = projectId,
        from: agentSessionsProvider,
        name: r'agentSessionsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$agentSessionsHash,
        dependencies: AgentSessionsFamily._dependencies,
        allTransitiveDependencies:
            AgentSessionsFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  AgentSessionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectId,
  }) : super.internal();

  final int? projectId;

  @override
  FutureOr<List<AgentSession>> runNotifierBuild(
    covariant AgentSessions notifier,
  ) {
    return notifier.build(projectId);
  }

  @override
  Override overrideWith(AgentSessions Function() create) {
    return ProviderOverride(
      origin: this,
      override: AgentSessionsProvider._internal(
        () => create()..projectId = projectId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        projectId: projectId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<AgentSessions, List<AgentSession>>
  createElement() {
    return _AgentSessionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentSessionsProvider && other.projectId == projectId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, projectId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AgentSessionsRef
    on AutoDisposeAsyncNotifierProviderRef<List<AgentSession>> {
  /// The parameter `projectId` of this provider.
  int? get projectId;
}

class _AgentSessionsProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          AgentSessions,
          List<AgentSession>
        >
    with AgentSessionsRef {
  _AgentSessionsProviderElement(super.provider);

  @override
  int? get projectId => (origin as AgentSessionsProvider).projectId;
}

String _$agentConversationHash() => r'249ab1a3ed43d011e9a3047564f05815bd125118';

abstract class _$AgentConversation
    extends BuildlessAutoDisposeNotifier<AgentConversationState> {
  late final int? projectId;

  AgentConversationState build(int? projectId);
}

/// See also [AgentConversation].
@ProviderFor(AgentConversation)
const agentConversationProvider = AgentConversationFamily();

/// See also [AgentConversation].
class AgentConversationFamily extends Family<AgentConversationState> {
  /// See also [AgentConversation].
  const AgentConversationFamily();

  /// See also [AgentConversation].
  AgentConversationProvider call(int? projectId) {
    return AgentConversationProvider(projectId);
  }

  @override
  AgentConversationProvider getProviderOverride(
    covariant AgentConversationProvider provider,
  ) {
    return call(provider.projectId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'agentConversationProvider';
}

/// See also [AgentConversation].
class AgentConversationProvider
    extends
        AutoDisposeNotifierProviderImpl<
          AgentConversation,
          AgentConversationState
        > {
  /// See also [AgentConversation].
  AgentConversationProvider(int? projectId)
    : this._internal(
        () => AgentConversation()..projectId = projectId,
        from: agentConversationProvider,
        name: r'agentConversationProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$agentConversationHash,
        dependencies: AgentConversationFamily._dependencies,
        allTransitiveDependencies:
            AgentConversationFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  AgentConversationProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectId,
  }) : super.internal();

  final int? projectId;

  @override
  AgentConversationState runNotifierBuild(
    covariant AgentConversation notifier,
  ) {
    return notifier.build(projectId);
  }

  @override
  Override overrideWith(AgentConversation Function() create) {
    return ProviderOverride(
      origin: this,
      override: AgentConversationProvider._internal(
        () => create()..projectId = projectId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        projectId: projectId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<AgentConversation, AgentConversationState>
  createElement() {
    return _AgentConversationProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AgentConversationProvider && other.projectId == projectId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, projectId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AgentConversationRef
    on AutoDisposeNotifierProviderRef<AgentConversationState> {
  /// The parameter `projectId` of this provider.
  int? get projectId;
}

class _AgentConversationProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          AgentConversation,
          AgentConversationState
        >
    with AgentConversationRef {
  _AgentConversationProviderElement(super.provider);

  @override
  int? get projectId => (origin as AgentConversationProvider).projectId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
