// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_minute_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentMinuteHash() => r'97dd8560426406c9240cf68342667278e7796815';

/// Hora atual com granularidade de minuto, compartilhada por ClockCard e
/// pelo header mobile.
///
/// O primeiro tick é alinhado ao próximo minuto cheio (não um
/// `Timer.periodic(Duration(minutes: 1))` cru, que deriva a cada ciclo).
/// No iOS o sistema suspende o app e o Timer não sobrevive: onPause cancela,
/// onResume refresca o valor na hora e re-arma. Mesmo padrão do
/// [AppLifecycleReconnect] — o gate `kIsWeb` mantém o comportamento web
/// idêntico ao de hoje (lá onPause/onResume nem disparam).
///
/// Copied from [CurrentMinute].
@ProviderFor(CurrentMinute)
final currentMinuteProvider =
    AutoDisposeNotifierProvider<CurrentMinute, DateTime>.internal(
      CurrentMinute.new,
      name: r'currentMinuteProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentMinuteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentMinute = AutoDisposeNotifier<DateTime>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
