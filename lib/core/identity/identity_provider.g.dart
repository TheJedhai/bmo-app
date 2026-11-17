// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadBadgesHash() => r'2de3c20b5e68a02a33150283f049953c72e85cb7';

/// Badges de não lidos por área, direto do `/api/v1/me`.
///
/// Provider separado do [CurrentUser] de propósito: atualizar o badge não
/// pode rebuildar o gate de identidade (spinner de tela cheia).
///
/// Copied from [unreadBadges].
@ProviderFor(unreadBadges)
final unreadBadgesProvider = AutoDisposeFutureProvider<UnreadCounts>.internal(
  unreadBadges,
  name: r'unreadBadgesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadBadgesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadBadgesRef = AutoDisposeFutureProviderRef<UnreadCounts>;
String _$currentUserHash() => r'36e11f4fbd5c02a8e78d5a3654dbe74b6f407eca';

/// See also [CurrentUser].
@ProviderFor(CurrentUser)
final currentUserProvider =
    AutoDisposeAsyncNotifierProvider<CurrentUser, UserProfile?>.internal(
      CurrentUser.new,
      name: r'currentUserProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentUserHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentUser = AutoDisposeAsyncNotifier<UserProfile?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
