// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memories_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memorySearchHash() => r'64d8618fb56716c58f840e05a7471a0e62045e7a';

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

/// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
///
/// É `family` por query: cada termo digitado gera uma instância, e o
/// `autoDispose` (default) descarta as antigas quando o campo muda.
///
/// Copied from [memorySearch].
@ProviderFor(memorySearch)
const memorySearchProvider = MemorySearchFamily();

/// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
///
/// É `family` por query: cada termo digitado gera uma instância, e o
/// `autoDispose` (default) descarta as antigas quando o campo muda.
///
/// Copied from [memorySearch].
class MemorySearchFamily extends Family<AsyncValue<List<Memory>>> {
  /// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
  ///
  /// É `family` por query: cada termo digitado gera uma instância, e o
  /// `autoDispose` (default) descarta as antigas quando o campo muda.
  ///
  /// Copied from [memorySearch].
  const MemorySearchFamily();

  /// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
  ///
  /// É `family` por query: cada termo digitado gera uma instância, e o
  /// `autoDispose` (default) descarta as antigas quando o campo muda.
  ///
  /// Copied from [memorySearch].
  MemorySearchProvider call(String query) {
    return MemorySearchProvider(query);
  }

  @override
  MemorySearchProvider getProviderOverride(
    covariant MemorySearchProvider provider,
  ) {
    return call(provider.query);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'memorySearchProvider';
}

/// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
///
/// É `family` por query: cada termo digitado gera uma instância, e o
/// `autoDispose` (default) descarta as antigas quando o campo muda.
///
/// Copied from [memorySearch].
class MemorySearchProvider extends AutoDisposeFutureProvider<List<Memory>> {
  /// Busca no servidor (`/memories/search`). Query vazia não bate na rede.
  ///
  /// É `family` por query: cada termo digitado gera uma instância, e o
  /// `autoDispose` (default) descarta as antigas quando o campo muda.
  ///
  /// Copied from [memorySearch].
  MemorySearchProvider(String query)
    : this._internal(
        (ref) => memorySearch(ref as MemorySearchRef, query),
        from: memorySearchProvider,
        name: r'memorySearchProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$memorySearchHash,
        dependencies: MemorySearchFamily._dependencies,
        allTransitiveDependencies:
            MemorySearchFamily._allTransitiveDependencies,
        query: query,
      );

  MemorySearchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.query,
  }) : super.internal();

  final String query;

  @override
  Override overrideWith(
    FutureOr<List<Memory>> Function(MemorySearchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MemorySearchProvider._internal(
        (ref) => create(ref as MemorySearchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        query: query,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Memory>> createElement() {
    return _MemorySearchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MemorySearchProvider && other.query == query;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, query.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MemorySearchRef on AutoDisposeFutureProviderRef<List<Memory>> {
  /// The parameter `query` of this provider.
  String get query;
}

class _MemorySearchProviderElement
    extends AutoDisposeFutureProviderElement<List<Memory>>
    with MemorySearchRef {
  _MemorySearchProviderElement(super.provider);

  @override
  String get query => (origin as MemorySearchProvider).query;
}

String _$memoriesScopeModeHash() => r'de0faa5af59810c377406fb8a55e1a38685951c0';

/// See also [MemoriesScopeMode].
@ProviderFor(MemoriesScopeMode)
final memoriesScopeModeProvider =
    AutoDisposeNotifierProvider<MemoriesScopeMode, MemoryScope>.internal(
      MemoriesScopeMode.new,
      name: r'memoriesScopeModeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$memoriesScopeModeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MemoriesScopeMode = AutoDisposeNotifier<MemoryScope>;
String _$memoriesHash() => r'2026e5ebc6e7d9c8e4b929b81fe26e6aca6c2749';

/// See also [Memories].
@ProviderFor(Memories)
final memoriesProvider =
    AutoDisposeAsyncNotifierProvider<Memories, List<Memory>>.internal(
      Memories.new,
      name: r'memoriesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$memoriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Memories = AutoDisposeAsyncNotifier<List<Memory>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
