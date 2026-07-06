import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flux_model.dart';

class SettingsApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const SettingsApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'SettingsApiException($statusCode, $errorCode): $message';
}

class SettingsClient {
  final http.Client _client;
  final String _baseUrl;

  SettingsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  /// GET /api/v1/settings
  /// Returns a flat map e.g. {"image.default_model": "flux-pro"} or {} if empty.
  Future<Map<String, String>> getAll() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/settings'),
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    return {};
  }

  /// PATCH /api/v1/settings
  /// Sends {key: value}, returns the final server state.
  Future<Map<String, String>> patch(Map<String, String> patches) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/settings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(patches),
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    return {};
  }

  /// GET /api/v1/images/models
  /// Returns the list of available FLUX models for the dropdown.
  Future<List<FluxModel>> getImageModels() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/images/models'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FluxModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
    throw SettingsApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
