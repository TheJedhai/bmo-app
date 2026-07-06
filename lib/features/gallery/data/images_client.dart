import 'dart:convert';

import 'package:http/http.dart' as http;

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
