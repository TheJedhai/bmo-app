import 'dart:convert';

import 'package:http/http.dart' as http;

import '../user_profile.dart';

class UsersClient {
  final http.Client _client;
  final String _baseUrl;

  UsersClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  /// GET /api/v1/users → lista de perfis disponíveis.
  Future<List<UserProfile>> getUsers() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/users'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw UsersApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Alguns servidores embrulham em {"users": [...]}.
    if (decoded is Map<String, dynamic>) {
      final list = decoded['users'];
      if (list is List) {
        return list
            .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    throw UsersApiException(
      response.statusCode,
      'Formato de resposta inesperado: ${response.body}',
    );
  }
}

class UsersApiException implements Exception {
  final int statusCode;
  final String body;

  const UsersApiException(this.statusCode, this.body);

  @override
  String toString() => 'UsersApiException($statusCode): $body';
}
