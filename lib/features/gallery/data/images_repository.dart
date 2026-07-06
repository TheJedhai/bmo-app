import 'package:bmo_app/features/settings/data/flux_model.dart';

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

  Future<List<FluxModel>> getModels() => _client.getModels();

  Future<GalleryImage> generateImg2img({
    required List<int> sourceBytes,
    required String fileName,
    required String prompt,
    String? negativePrompt,
    String? model,
    double? strength,
    int? width,
    int? height,
    int? steps,
    int? seed,
  }) =>
      _client.generateImg2img(
        sourceBytes: sourceBytes,
        fileName: fileName,
        prompt: prompt,
        negativePrompt: negativePrompt,
        model: model,
        strength: strength,
        width: width,
        height: height,
        steps: steps,
        seed: seed,
      );
}
