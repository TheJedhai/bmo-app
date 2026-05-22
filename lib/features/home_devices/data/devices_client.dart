import 'dart:convert';

import 'package:http/http.dart' as http;

class MqttUnavailableException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const MqttUnavailableException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => 'MqttUnavailableException($statusCode, $errorCode): $message';
}

class DevicesClient {
  final http.Client _client;
  final String _baseUrl;

  DevicesClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Future<List<Map<String, dynamic>>> listLights() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/lights'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> turnOn(String name) => _post('/api/v1/lights/$name/on');

  Future<void> turnOff(String name) => _post('/api/v1/lights/$name/off');

  Future<void> toggle(String name) => _post('/api/v1/lights/$name/toggle');

  Future<void> _post(String path) async {
    final response = await _client.post(Uri.parse('$_baseUrl$path'));
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String errorCode = '';
    String message = response.body;

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      errorCode = body['error'] as String? ?? '';
      message = body['message'] as String? ?? response.body;
    } catch (_) {}

    if (response.statusCode == 503) {
      throw MqttUnavailableException(
        statusCode: response.statusCode,
        errorCode: errorCode,
        message: message,
      );
    }

    throw MqttUnavailableException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
