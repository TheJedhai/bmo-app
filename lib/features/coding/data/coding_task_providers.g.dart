// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coding_task_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$codingTaskHash() => r'3fa671bb9ecc0f99a13d7e2c7d47b5a4df5fc55a';

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

/// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
/// pelo detalhe, re-sincronizado no reconnect do SSE.
///
/// Copied from [codingTask].
@ProviderFor(codingTask)
const codingTaskProvider = CodingTaskFamily();

/// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
/// pelo detalhe, re-sincronizado no reconnect do SSE.
///
/// Copied from [codingTask].
class CodingTaskFamily extends Family<AsyncValue<CodingTask>> {
  /// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
  /// pelo detalhe, re-sincronizado no reconnect do SSE.
  ///
  /// Copied from [codingTask].
  const CodingTaskFamily();

  /// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
  /// pelo detalhe, re-sincronizado no reconnect do SSE.
  ///
  /// Copied from [codingTask].
  CodingTaskProvider call(int taskId) {
    return CodingTaskProvider(taskId);
  }

  @override
  CodingTaskProvider getProviderOverride(
    covariant CodingTaskProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'codingTaskProvider';
}

/// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
/// pelo detalhe, re-sincronizado no reconnect do SSE.
///
/// Copied from [codingTask].
class CodingTaskProvider extends AutoDisposeFutureProvider<CodingTask> {
  /// Snapshot REST de uma tarefa (com `steps[]`) — usado pelo card no mount e
  /// pelo detalhe, re-sincronizado no reconnect do SSE.
  ///
  /// Copied from [codingTask].
  CodingTaskProvider(int taskId)
    : this._internal(
        (ref) => codingTask(ref as CodingTaskRef, taskId),
        from: codingTaskProvider,
        name: r'codingTaskProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingTaskHash,
        dependencies: CodingTaskFamily._dependencies,
        allTransitiveDependencies: CodingTaskFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  CodingTaskProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final int taskId;

  @override
  Override overrideWith(
    FutureOr<CodingTask> Function(CodingTaskRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CodingTaskProvider._internal(
        (ref) => create(ref as CodingTaskRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<CodingTask> createElement() {
    return _CodingTaskProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingTaskProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CodingTaskRef on AutoDisposeFutureProviderRef<CodingTask> {
  /// The parameter `taskId` of this provider.
  int get taskId;
}

class _CodingTaskProviderElement
    extends AutoDisposeFutureProviderElement<CodingTask>
    with CodingTaskRef {
  _CodingTaskProviderElement(super.provider);

  @override
  int get taskId => (origin as CodingTaskProvider).taskId;
}

String _$codingTasksHash() => r'4622fb3b45a80a14d4db240344e97ab3cdb78f53';

abstract class _$CodingTasks
    extends BuildlessAutoDisposeAsyncNotifier<List<CodingTask>> {
  late final int projectId;

  FutureOr<List<CodingTask>> build(int projectId);
}

/// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
/// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
/// O `patch` é o objeto completo do card (sem `steps`).
///
/// Copied from [CodingTasks].
@ProviderFor(CodingTasks)
const codingTasksProvider = CodingTasksFamily();

/// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
/// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
/// O `patch` é o objeto completo do card (sem `steps`).
///
/// Copied from [CodingTasks].
class CodingTasksFamily extends Family<AsyncValue<List<CodingTask>>> {
  /// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
  /// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
  /// O `patch` é o objeto completo do card (sem `steps`).
  ///
  /// Copied from [CodingTasks].
  const CodingTasksFamily();

  /// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
  /// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
  /// O `patch` é o objeto completo do card (sem `steps`).
  ///
  /// Copied from [CodingTasks].
  CodingTasksProvider call(int projectId) {
    return CodingTasksProvider(projectId);
  }

  @override
  CodingTasksProvider getProviderOverride(
    covariant CodingTasksProvider provider,
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
  String? get name => r'codingTasksProvider';
}

/// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
/// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
/// O `patch` é o objeto completo do card (sem `steps`).
///
/// Copied from [CodingTasks].
class CodingTasksProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<CodingTasks, List<CodingTask>> {
  /// Tarefas de um projeto (mais recentes primeiro), mantidas ao vivo pelos
  /// eventos `coding.task.created` e `coding.task.updated` do `/api/v1/stream`.
  /// O `patch` é o objeto completo do card (sem `steps`).
  ///
  /// Copied from [CodingTasks].
  CodingTasksProvider(int projectId)
    : this._internal(
        () => CodingTasks()..projectId = projectId,
        from: codingTasksProvider,
        name: r'codingTasksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingTasksHash,
        dependencies: CodingTasksFamily._dependencies,
        allTransitiveDependencies: CodingTasksFamily._allTransitiveDependencies,
        projectId: projectId,
      );

  CodingTasksProvider._internal(
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
  FutureOr<List<CodingTask>> runNotifierBuild(covariant CodingTasks notifier) {
    return notifier.build(projectId);
  }

  @override
  Override overrideWith(CodingTasks Function() create) {
    return ProviderOverride(
      origin: this,
      override: CodingTasksProvider._internal(
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
  AutoDisposeAsyncNotifierProviderElement<CodingTasks, List<CodingTask>>
  createElement() {
    return _CodingTasksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingTasksProvider && other.projectId == projectId;
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
mixin CodingTasksRef on AutoDisposeAsyncNotifierProviderRef<List<CodingTask>> {
  /// The parameter `projectId` of this provider.
  int get projectId;
}

class _CodingTasksProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<CodingTasks, List<CodingTask>>
    with CodingTasksRef {
  _CodingTasksProviderElement(super.provider);

  @override
  int get projectId => (origin as CodingTasksProvider).projectId;
}

String _$codingTaskLiveHash() => r'293a7db53d462c219c71ba4058e59c36d7a34cdb';

abstract class _$CodingTaskLive
    extends BuildlessNotifier<Map<String, dynamic>?> {
  late final int taskId;

  Map<String, dynamic>? build(int taskId);
}

/// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
/// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
/// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
///
/// Copied from [CodingTaskLive].
@ProviderFor(CodingTaskLive)
const codingTaskLiveProvider = CodingTaskLiveFamily();

/// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
/// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
/// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
///
/// Copied from [CodingTaskLive].
class CodingTaskLiveFamily extends Family<Map<String, dynamic>?> {
  /// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
  /// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
  /// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
  ///
  /// Copied from [CodingTaskLive].
  const CodingTaskLiveFamily();

  /// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
  /// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
  /// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
  ///
  /// Copied from [CodingTaskLive].
  CodingTaskLiveProvider call(int taskId) {
    return CodingTaskLiveProvider(taskId);
  }

  @override
  CodingTaskLiveProvider getProviderOverride(
    covariant CodingTaskLiveProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'codingTaskLiveProvider';
}

/// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
/// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
/// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
///
/// Copied from [CodingTaskLive].
class CodingTaskLiveProvider
    extends NotifierProviderImpl<CodingTaskLive, Map<String, dynamic>?> {
  /// Último objeto vivo de uma tarefa (`coding.task.* {patch}` e o
  /// `rich.update` do card), guardado por task id. Sobrevive ao unmount do card
  /// (`keepAlive`): o payload do bloco no histórico é o do momento da criação.
  ///
  /// Copied from [CodingTaskLive].
  CodingTaskLiveProvider(int taskId)
    : this._internal(
        () => CodingTaskLive()..taskId = taskId,
        from: codingTaskLiveProvider,
        name: r'codingTaskLiveProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingTaskLiveHash,
        dependencies: CodingTaskLiveFamily._dependencies,
        allTransitiveDependencies:
            CodingTaskLiveFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  CodingTaskLiveProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final int taskId;

  @override
  Map<String, dynamic>? runNotifierBuild(covariant CodingTaskLive notifier) {
    return notifier.build(taskId);
  }

  @override
  Override overrideWith(CodingTaskLive Function() create) {
    return ProviderOverride(
      origin: this,
      override: CodingTaskLiveProvider._internal(
        () => create()..taskId = taskId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  NotifierProviderElement<CodingTaskLive, Map<String, dynamic>?>
  createElement() {
    return _CodingTaskLiveProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingTaskLiveProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CodingTaskLiveRef on NotifierProviderRef<Map<String, dynamic>?> {
  /// The parameter `taskId` of this provider.
  int get taskId;
}

class _CodingTaskLiveProviderElement
    extends NotifierProviderElement<CodingTaskLive, Map<String, dynamic>?>
    with CodingTaskLiveRef {
  _CodingTaskLiveProviderElement(super.provider);

  @override
  int get taskId => (origin as CodingTaskLiveProvider).taskId;
}

String _$codingStepRunsHash() => r'c1b76bfb996d4da509e428890a703f349cbf4d5b';

abstract class _$CodingStepRuns
    extends BuildlessNotifier<Map<int, Map<String, dynamic>>> {
  late final int stepId;

  Map<int, Map<String, dynamic>> build(int stepId);
}

/// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
///
/// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
/// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
/// uma lista paginada (`GET /coding/runs?step_id=`).
///
/// Copied from [CodingStepRuns].
@ProviderFor(CodingStepRuns)
const codingStepRunsProvider = CodingStepRunsFamily();

/// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
///
/// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
/// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
/// uma lista paginada (`GET /coding/runs?step_id=`).
///
/// Copied from [CodingStepRuns].
class CodingStepRunsFamily extends Family<Map<int, Map<String, dynamic>>> {
  /// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
  ///
  /// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
  /// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
  /// uma lista paginada (`GET /coding/runs?step_id=`).
  ///
  /// Copied from [CodingStepRuns].
  const CodingStepRunsFamily();

  /// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
  ///
  /// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
  /// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
  /// uma lista paginada (`GET /coding/runs?step_id=`).
  ///
  /// Copied from [CodingStepRuns].
  CodingStepRunsProvider call(int stepId) {
    return CodingStepRunsProvider(stepId);
  }

  @override
  CodingStepRunsProvider getProviderOverride(
    covariant CodingStepRunsProvider provider,
  ) {
    return call(provider.stepId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'codingStepRunsProvider';
}

/// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
///
/// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
/// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
/// uma lista paginada (`GET /coding/runs?step_id=`).
///
/// Copied from [CodingStepRuns].
class CodingStepRunsProvider
    extends
        NotifierProviderImpl<CodingStepRuns, Map<int, Map<String, dynamic>>> {
  /// Tentativas (runs) de um passo, ao vivo por `coding.run.* {patch.step_id}`.
  ///
  /// ponytail: o REST de runs não expõe `step_id`, então só as tentativas
  /// vistas nesta sessão aparecem. Se o servidor passar a expor, trocar por
  /// uma lista paginada (`GET /coding/runs?step_id=`).
  ///
  /// Copied from [CodingStepRuns].
  CodingStepRunsProvider(int stepId)
    : this._internal(
        () => CodingStepRuns()..stepId = stepId,
        from: codingStepRunsProvider,
        name: r'codingStepRunsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$codingStepRunsHash,
        dependencies: CodingStepRunsFamily._dependencies,
        allTransitiveDependencies:
            CodingStepRunsFamily._allTransitiveDependencies,
        stepId: stepId,
      );

  CodingStepRunsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.stepId,
  }) : super.internal();

  final int stepId;

  @override
  Map<int, Map<String, dynamic>> runNotifierBuild(
    covariant CodingStepRuns notifier,
  ) {
    return notifier.build(stepId);
  }

  @override
  Override overrideWith(CodingStepRuns Function() create) {
    return ProviderOverride(
      origin: this,
      override: CodingStepRunsProvider._internal(
        () => create()..stepId = stepId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        stepId: stepId,
      ),
    );
  }

  @override
  NotifierProviderElement<CodingStepRuns, Map<int, Map<String, dynamic>>>
  createElement() {
    return _CodingStepRunsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CodingStepRunsProvider && other.stepId == stepId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, stepId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CodingStepRunsRef on NotifierProviderRef<Map<int, Map<String, dynamic>>> {
  /// The parameter `stepId` of this provider.
  int get stepId;
}

class _CodingStepRunsProviderElement
    extends
        NotifierProviderElement<CodingStepRuns, Map<int, Map<String, dynamic>>>
    with CodingStepRunsRef {
  _CodingStepRunsProviderElement(super.provider);

  @override
  int get stepId => (origin as CodingStepRunsProvider).stepId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
