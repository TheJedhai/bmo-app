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
    MemoryScope? scope,
    String? source,
    int? limit,
    int? offset,
  }) async {
    return _getList('/api/v1/memories', {
      'scope': ?scope?.wire,
      'source': ?source,
      'limit': ?limit?.toString(),
      'offset': ?offset?.toString(),
    });
  }

  /// Busca textual + semântica (`GET /api/v1/memories/search`). O servidor
  /// devolve `score` em cada item; a ordem já vem por relevância.
  Future<List<Memory>> search({
    required String query,
    MemoryScope? scope,
    int? limit,
  }) async {
    return _getList('/api/v1/memories/search', {
      'q': query,
      'scope': ?scope?.wire,
      'limit': ?limit?.toString(),
    });
  }

  Future<List<Memory>> _getList(
    String path,
    Map<String, String> queryParams,
  ) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/v1/memories/{id}`. 404 = memória apagada (`memory_not_found`).
  Future<Memory> get(int id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/memories/$id'),
    );
    _ensureOk(response);
    return Memory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Memory> create(String content, {bool personal = false}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/memories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content, 'personal': personal}),
    );
    _ensureOk(response);
    return Memory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Atualiza só os campos enviados (`personal` ausente = não mexe no escopo).
  Future<Memory> update(
    int id, {
    String? content,
    bool? personal,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/memories/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': ?content,
        'personal': ?personal,
      }),
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
