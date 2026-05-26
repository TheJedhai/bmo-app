import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_position.dart';

class DevicePositionsClient {
  final http.Client _client;
  final String _baseUrl;

  DevicePositionsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Future<List<DevicePosition>> listPositions() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/device-positions'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => DevicePosition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> setPosition(String name, double x, double y) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/v1/device-positions/$name'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'x': x, 'y': y}),
    );
    _ensureOk(response);
  }

  Future<void> clearPosition(String name) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/device-positions/$name'),
    );
    _ensureOk(response);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'DevicePositionsClient error ${response.statusCode}: ${response.body}',
    );
  }
}
