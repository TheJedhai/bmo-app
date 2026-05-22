// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'devices_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$devicesHash() => r'4100f271b52edc9ebe21205dceae02636305dceb';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
