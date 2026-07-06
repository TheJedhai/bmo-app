import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:bmo_app/features/settings/data/flux_model.dart';
import 'image_model.dart';

class ImagesApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const ImagesApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'ImagesApiException($statusCode, $errorCode): $message';
}

class ImagesClient {
  final http.Client _client;
  final String _baseUrl;

  ImagesClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  /// GET /api/v1/images?mode=...
  Future<List<GalleryImage>> list({String? mode}) async {
    final queryParams = <String, String>{};
    if (mode != null && mode.isNotEmpty) queryParams['mode'] = mode;

    final uri = Uri.parse('$_baseUrl/api/v1/images').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GalleryImage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/v1/images/models
  Future<List<FluxModel>> getModels() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/images/models'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FluxModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/images/img2img (multipart)
  ///
  /// Sends the source image and generation parameters. Returns the created
  /// [GalleryImage] with status "pending". The actual generation runs
  /// asynchronously; the gallery picks up progress via SSE.
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
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/images/img2img');
    final request = http.MultipartRequest('POST', uri);

    request.fields['prompt'] = prompt;
    if (negativePrompt != null && negativePrompt.isNotEmpty) {
      request.fields['negative_prompt'] = negativePrompt;
    }
    if (model != null && model.isNotEmpty) {
      request.fields['model'] = model;
    }
    if (strength != null) {
      request.fields['strength'] = strength.toString();
    }
    if (width != null) {
      request.fields['width'] = width.toString();
    }
    if (height != null) {
      request.fields['height'] = height.toString();
    }
    if (steps != null) {
      request.fields['steps'] = steps.toString();
    }
    if (seed != null) {
      request.fields['seed'] = seed.toString();
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      sourceBytes,
      filename: fileName,
    ));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    _ensureOk(response);
    return GalleryImage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// DELETE /api/v1/images/{id}
  Future<void> delete(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/images/$id'),
    );
    if (response.statusCode == 204) return;
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String errorCode = 'unknown';
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        errorCode = decoded['error'] as String? ?? 'unknown';
        message = decoded['message'] as String? ?? response.body;
      }
    } catch (_) {
      // corpo não é JSON; usa o body bruto como message
    }
    throw ImagesApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
