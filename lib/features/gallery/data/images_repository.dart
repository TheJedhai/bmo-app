import 'image_model.dart';
import 'images_client.dart';

/// Thin wrapper over [ImagesClient]. Exists so the architecture is ready
/// for future caching, offline support, or persistence layers.
class ImagesRepository {
  final ImagesClient _client;

  ImagesRepository(this._client);

  Future<List<GalleryImage>> list({String? mode}) =>
      _client.list(mode: mode);

  Future<void> delete(int id) => _client.delete(id);
}
