import 'flux_model.dart';
import 'settings_client.dart';

/// Thin wrapper over [SettingsClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class SettingsRepository {
  final SettingsClient _client;

  SettingsRepository(this._client);

  Future<Map<String, String>> getAll() => _client.getAll();

  Future<Map<String, String>> patch(Map<String, String> patches) =>
      _client.patch(patches);

  Future<List<FluxModel>> getImageModels() => _client.getImageModels();
}
