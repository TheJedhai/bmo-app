// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rss_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadCountHash() => r'c4119b68b48a144bda6798b6630d9fe7e4b5725f';

/// See also [unreadCount].
@ProviderFor(unreadCount)
final unreadCountProvider = AutoDisposeFutureProvider<int>.internal(
  unreadCount,
  name: r'unreadCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadCountRef = AutoDisposeFutureProviderRef<int>;
String _$feedsHash() => r'0b462212878cae6622d8cdefd70575d9c59736cc';

/// See also [Feeds].
@ProviderFor(Feeds)
final feedsProvider =
    AutoDisposeAsyncNotifierProvider<Feeds, List<Feed>>.internal(
      Feeds.new,
      name: r'feedsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$feedsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Feeds = AutoDisposeAsyncNotifier<List<Feed>>;
String _$articlesHash() => r'78061988a030b08c424b8b884332ff081980b5a2';

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

abstract class _$Articles
    extends BuildlessAutoDisposeAsyncNotifier<List<Article>> {
  late final ({
    int? feedId,
    bool? isRead,
    bool? isStarred,
    String? titleContains,
  })
  filter;

  FutureOr<List<Article>> build(
    ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
    filter,
  );
}

/// See also [Articles].
@ProviderFor(Articles)
const articlesProvider = ArticlesFamily();

/// See also [Articles].
class ArticlesFamily extends Family<AsyncValue<List<Article>>> {
  /// See also [Articles].
  const ArticlesFamily();

  /// See also [Articles].
  ArticlesProvider call(
    ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
    filter,
  ) {
    return ArticlesProvider(filter);
  }

  @override
  ArticlesProvider getProviderOverride(covariant ArticlesProvider provider) {
    return call(provider.filter);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'articlesProvider';
}

/// See also [Articles].
class ArticlesProvider
    extends AutoDisposeAsyncNotifierProviderImpl<Articles, List<Article>> {
  /// See also [Articles].
  ArticlesProvider(
    ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
    filter,
  ) : this._internal(
        () => Articles()..filter = filter,
        from: articlesProvider,
        name: r'articlesProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$articlesHash,
        dependencies: ArticlesFamily._dependencies,
        allTransitiveDependencies: ArticlesFamily._allTransitiveDependencies,
        filter: filter,
      );

  ArticlesProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.filter,
  }) : super.internal();

  final ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
  filter;

  @override
  FutureOr<List<Article>> runNotifierBuild(covariant Articles notifier) {
    return notifier.build(filter);
  }

  @override
  Override overrideWith(Articles Function() create) {
    return ProviderOverride(
      origin: this,
      override: ArticlesProvider._internal(
        () => create()..filter = filter,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        filter: filter,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<Articles, List<Article>>
  createElement() {
    return _ArticlesProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ArticlesProvider && other.filter == filter;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, filter.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ArticlesRef on AutoDisposeAsyncNotifierProviderRef<List<Article>> {
  /// The parameter `filter` of this provider.
  ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
  get filter;
}

class _ArticlesProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<Articles, List<Article>>
    with ArticlesRef {
  _ArticlesProviderElement(super.provider);

  @override
  ({int? feedId, bool? isRead, bool? isStarred, String? titleContains})
  get filter => (origin as ArticlesProvider).filter;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
