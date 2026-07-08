// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarms_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$scenesHash() => r'dd92c3d4fc46872557679555b44adf97b0f0264c';

/// See also [scenes].
@ProviderFor(scenes)
final scenesProvider = AutoDisposeFutureProvider<List<Scene>>.internal(
  scenes,
  name: r'scenesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$scenesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ScenesRef = AutoDisposeFutureProviderRef<List<Scene>>;
String _$alarmsNotifierHash() => r'dbf716c263c1ec2ee1d79a52475e2c3de64a5530';

/// See also [AlarmsNotifier].
@ProviderFor(AlarmsNotifier)
final alarmsNotifierProvider =
    AutoDisposeAsyncNotifierProvider<
      AlarmsNotifier,
      List<DeviceAlarm>
    >.internal(
      AlarmsNotifier.new,
      name: r'alarmsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$alarmsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AlarmsNotifier = AutoDisposeAsyncNotifier<List<DeviceAlarm>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
