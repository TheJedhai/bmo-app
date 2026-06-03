// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$devicesHash() => r'850df45f7d104e8d417508514f0f588f5dc0be48';

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
String _$devicePositionsHash() => r'987bbcd77f30ca2d955ab16ea045d4dcbbc35238';

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

typedef _$DevicePositions =
    AutoDisposeAsyncNotifier<Map<String, DevicePosition>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
