import 'dart:convert';

import 'package:http/http.dart' as http;

import 'memory_model.dart';

class MemoriesApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const MemoriesApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'MemoriesApiException($statusCode, $errorCode): $message';
}

class MemoriesClient {
  final http.Client _client;
  final String _baseUrl;

  MemoriesClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Future<List<Memory>> list({
    String? source,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (source != null) queryParams['source'] = source;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final uri = Uri.parse('$_baseUrl/api/v1/memories').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Memory> create(String content) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/memories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
    );
    _ensureOk(response);
    return Memory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Memory> update(int id, String content) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/memories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
    );
    _ensureOk(response);
    return Memory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/memories/$id'),
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
    throw MemoriesApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
