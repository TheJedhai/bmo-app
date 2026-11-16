import 'memory_model.dart';
import 'memories_client.dart';

/// Thin wrapper over [MemoriesClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class MemoriesRepository {
  final MemoriesClient _client;

  MemoriesRepository(this._client);

  Future<List<Memory>> list({
    MemoryScope? scope,
    String? source,
    int? limit,
    int? offset,
  }) =>
      _client.list(scope: scope, source: source, limit: limit, offset: offset);

  Future<List<Memory>> search({
    required String query,
    MemoryScope? scope,
    int? limit,
  }) =>
      _client.search(query: query, scope: scope, limit: limit);

  Future<Memory> get(int id) => _client.get(id);

  Future<Memory> create(String content, {bool personal = false}) =>
      _client.create(content, personal: personal);

  Future<Memory> update(int id, {String? content, bool? personal}) =>
      _client.update(id, content: content, personal: personal);

  Future<void> delete(int id) => _client.delete(id);
}
