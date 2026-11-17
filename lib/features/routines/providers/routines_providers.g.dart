// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routines_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$routinesRepositoryHash() =>
    r'c11d9c736ae8fd8be7fe9874dde12d221ca6cc9e';

/// See also [routinesRepository].
@ProviderFor(routinesRepository)
final routinesRepositoryProvider =
    AutoDisposeProvider<RoutinesRepository>.internal(
      routinesRepository,
      name: r'routinesRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$routinesRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RoutinesRepositoryRef = AutoDisposeProviderRef<RoutinesRepository>;
String _$presenceControllerHash() =>
    r'cc3b4f2727f4fd222d8de88cae9b9eaf760b8da8';

/// Presença atual. Relê na reconexão do SSE e na troca de perfil; não há
/// evento de presença no `/api/v1/stream` (o servidor não publica um).
///
/// Copied from [PresenceController].
@ProviderFor(PresenceController)
final presenceControllerProvider =
    AutoDisposeAsyncNotifierProvider<PresenceController, Presence>.internal(
      PresenceController.new,
      name: r'presenceControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$presenceControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PresenceController = AutoDisposeAsyncNotifier<Presence>;
String _$notificationsHash() => r'b28dfaf2c750f51f1e5b7f3e32cd424e402552f0';

/// See also [Notifications].
@ProviderFor(Notifications)
final notificationsProvider =
    AutoDisposeAsyncNotifierProvider<Notifications, NotificationsPage>.internal(
      Notifications.new,
      name: r'notificationsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$notificationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Notifications = AutoDisposeAsyncNotifier<NotificationsPage>;
String _$routineConfigHash() => r'208f12d0259a3c20ef558acf6c7d6c9b100cfa5c';

/// See also [RoutineConfig].
@ProviderFor(RoutineConfig)
final routineConfigProvider =
    AutoDisposeAsyncNotifierProvider<RoutineConfig, RoutineSettings>.internal(
      RoutineConfig.new,
      name: r'routineConfigProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$routineConfigHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RoutineConfig = AutoDisposeAsyncNotifier<RoutineSettings>;
String _$triggersHash() => r'ab9e2f081c4451c6bf01660f27edc16ebc7c9e10';

/// See also [Triggers].
@ProviderFor(Triggers)
final triggersProvider =
    AutoDisposeAsyncNotifierProvider<Triggers, List<RoutineTrigger>>.internal(
      Triggers.new,
      name: r'triggersProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$triggersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Triggers = AutoDisposeAsyncNotifier<List<RoutineTrigger>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
