import 'memory_model.dart';
import 'memories_client.dart';

/// Thin wrapper over [MemoriesClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class MemoriesRepository {
  final MemoriesClient _client;

  MemoriesRepository(this._client);

  Future<List<Memory>> list({
    String? source,
    int? limit,
    int? offset,
  }) =>
      _client.list(source: source, limit: limit, offset: offset);

  Future<Memory> create(String content) => _client.create(content);

  Future<Memory> update(int id, String content) =>
      _client.update(id, content);

  Future<void> delete(int id) => _client.delete(id);
}
