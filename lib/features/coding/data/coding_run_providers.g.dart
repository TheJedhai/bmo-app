// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coding_run_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$codingRunsHash() => r'6077b93bbcb13e1711fb7ef7499d32ece9391477';

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

/// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
/// devolve).
///
/// Copied from [codingRuns].
@ProviderFor(codingRuns)
const codingRunsProvider = CodingRunsFamily();

/// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
/// devolve).
///
/// Copied from [codingRuns].
class CodingRunsFamily extends Family<AsyncValue<List<CodingRun>>> {
  /// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
  /// devolve).
  ///
  /// Copied from [codingRuns].
  const CodingRunsFamily();

  /// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
  /// devolve).
  ///
  /// Copied from [codingRuns].
  CodingRunsProvider call(int projectId) {
    return CodingRunsProvider(projectId);
  }

  @override
  CodingRunsProvider getProviderOverride(
    covariant CodingRunsProvider provider,
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
  String? get name => r'codingRunsProvider';
}

/// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
/// devolve).
///
/// Copied from [codingRuns].
class CodingRunsProvider extends AutoDisposeFutureProvider<List<CodingRun>> {
  /// Histórico de runs de um projeto (mais recentes primeiro, como o servidor
  /// devolve).
  ///
  /// Copied from [codingRuns].
  CodingRunsProvider(int projectId)
    : this._internal(
        (ref) => codingRuns(ref as CodingRunsRef, projectId),
        from: codingRunsProvider,
        name: r'codingRunsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingRunsHash,
        dependencies: CodingRunsFamily._dependencies,
        allTransitiveDependencies: CodingRunsFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  CodingRunsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.projectId,
  }) : super.internal();

  final int projectId;

  @override
  Override overrideWith(
    FutureOr<List<CodingRun>> Function(CodingRunsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CodingRunsProvider._internal(
        (ref) => create(ref as CodingRunsRef),
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
  AutoDisposeFutureProviderElement<List<CodingRun>> createElement() {
    return _CodingRunsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingRunsProvider && other.projectId == projectId;
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
mixin CodingRunsRef on AutoDisposeFutureProviderRef<List<CodingRun>> {
  /// The parameter `projectId` of this provider.
  int get projectId;
}

class _CodingRunsProviderElement
    extends AutoDisposeFutureProviderElement<List<CodingRun>>
    with CodingRunsRef {
  _CodingRunsProviderElement(super.provider);

  @override
  int get projectId => (origin as CodingRunsProvider).projectId;
}

String _$codingRunHash() => r'9e36b904ca99ae07a6e4e7ab87a53883a1e36882';

/// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
/// rico no mount e no reconnect do SSE.
///
/// Copied from [codingRun].
@ProviderFor(codingRun)
const codingRunProvider = CodingRunFamily();

/// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
/// rico no mount e no reconnect do SSE.
///
/// Copied from [codingRun].
class CodingRunFamily extends Family<AsyncValue<CodingRun>> {
  /// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
  /// rico no mount e no reconnect do SSE.
  ///
  /// Copied from [codingRun].
  const CodingRunFamily();

  /// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
  /// rico no mount e no reconnect do SSE.
  ///
  /// Copied from [codingRun].
  CodingRunProvider call(int runId) {
    return CodingRunProvider(runId);
  }

  @override
  CodingRunProvider getProviderOverride(covariant CodingRunProvider provider) {
    return call(provider.runId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'codingRunProvider';
}

/// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
/// rico no mount e no reconnect do SSE.
///
/// Copied from [codingRun].
class CodingRunProvider extends AutoDisposeFutureProvider<CodingRun> {
  /// Snapshot REST de um run — usado pelo detalhe e re-sincronizado pelo card
  /// rico no mount e no reconnect do SSE.
  ///
  /// Copied from [codingRun].
  CodingRunProvider(int runId)
    : this._internal(
        (ref) => codingRun(ref as CodingRunRef, runId),
        from: codingRunProvider,
        name: r'codingRunProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingRunHash,
        dependencies: CodingRunFamily._dependencies,
        allTransitiveDependencies: CodingRunFamily._allTransitiveDependencies,
        runId: runId,
      );

  CodingRunProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.runId,
  }) : super.internal();

  final int runId;

  @override
  Override overrideWith(
    FutureOr<CodingRun> Function(CodingRunRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CodingRunProvider._internal(
        (ref) => create(ref as CodingRunRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        runId: runId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<CodingRun> createElement() {
    return _CodingRunProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingRunProvider && other.runId == runId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, runId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CodingRunRef on AutoDisposeFutureProviderRef<CodingRun> {
  /// The parameter `runId` of this provider.
  int get runId;
}

class _CodingRunProviderElement
    extends AutoDisposeFutureProviderElement<CodingRun>
    with CodingRunRef {
  _CodingRunProviderElement(super.provider);

  @override
  int get runId => (origin as CodingRunProvider).runId;
}

String _$codingRunEventsHash() => r'ebd9713a305dd4b1de709585f75aba01ba2701ed';

abstract class _$CodingRunEvents
    extends BuildlessAutoDisposeAsyncNotifier<List<CodingRunEvent>> {
  late final int runId;

  FutureOr<List<CodingRunEvent>> build(int runId);
}

/// Eventos do run, paginados por `after_seq`.
///
/// Copied from [CodingRunEvents].
@ProviderFor(CodingRunEvents)
const codingRunEventsProvider = CodingRunEventsFamily();

/// Eventos do run, paginados por `after_seq`.
///
/// Copied from [CodingRunEvents].
class CodingRunEventsFamily extends Family<AsyncValue<List<CodingRunEvent>>> {
  /// Eventos do run, paginados por `after_seq`.
  ///
  /// Copied from [CodingRunEvents].
  const CodingRunEventsFamily();

  /// Eventos do run, paginados por `after_seq`.
  ///
  /// Copied from [CodingRunEvents].
  CodingRunEventsProvider call(int runId) {
    return CodingRunEventsProvider(runId);
  }

  @override
  CodingRunEventsProvider getProviderOverride(
    covariant CodingRunEventsProvider provider,
  ) {
    return call(provider.runId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'codingRunEventsProvider';
}

/// Eventos do run, paginados por `after_seq`.
///
/// Copied from [CodingRunEvents].
class CodingRunEventsProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<
          CodingRunEvents,
          List<CodingRunEvent>
        > {
  /// Eventos do run, paginados por `after_seq`.
  ///
  /// Copied from [CodingRunEvents].
  CodingRunEventsProvider(int runId)
    : this._internal(
        () => CodingRunEvents()..runId = runId,
        from: codingRunEventsProvider,
        name: r'codingRunEventsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingRunEventsHash,
        dependencies: CodingRunEventsFamily._dependencies,
        allTransitiveDependencies:
            CodingRunEventsFamily._allTransitiveDependencies,
        runId: runId,
      );

  CodingRunEventsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.runId,
  }) : super.internal();

  final int runId;

  @override
  FutureOr<List<CodingRunEvent>> runNotifierBuild(
    covariant CodingRunEvents notifier,
  ) {
    return notifier.build(runId);
  }

  @override
  Override overrideWith(CodingRunEvents Function() create) {
    return ProviderOverride(
      origin: this,
      override: CodingRunEventsProvider._internal(
        () => create()..runId = runId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        runId: runId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<CodingRunEvents, List<CodingRunEvent>>
  createElement() {
    return _CodingRunEventsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingRunEventsProvider && other.runId == runId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, runId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CodingRunEventsRef
    on AutoDisposeAsyncNotifierProviderRef<List<CodingRunEvent>> {
  /// The parameter `runId` of this provider.
  int get runId;
}

class _CodingRunEventsProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<
          CodingRunEvents,
          List<CodingRunEvent>
        >
    with CodingRunEventsRef {
  _CodingRunEventsProviderElement(super.provider);

  @override
  int get runId => (origin as CodingRunEventsProvider).runId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
