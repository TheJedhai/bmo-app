// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$devicesHash() => r'904c9ea2abfa10046af712ef442c66bdd764823d';

/// See also [Devices].
@ProviderFor(Devices)
final devicesProvider =
    AutoDisposeAsyncNotifierProvider<
      Devices,
      Map<String, LightDevice>
    >.internal(
      Devices.new,
      name: r'devicesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$devicesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Devices = AutoDisposeAsyncNotifier<Map<String, LightDevice>>;

String _$devicePositionsHash() => r'1b2f5e8c3a9d7f6e4b1c0d8a5f3e7c2b9a6d0f4e';

/// See also [DevicePositions].
@ProviderFor(DevicePositions)
final devicePositionsProvider =
    AutoDisposeAsyncNotifierProvider<
      DevicePositions,
      Map<String, DevicePosition>
    >.internal(
      DevicePositions.new,
      name: r'devicePositionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$devicePositionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DevicePositions = AutoDisposeAsyncNotifier<Map<String, DevicePosition>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
