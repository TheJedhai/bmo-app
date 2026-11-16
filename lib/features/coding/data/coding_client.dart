import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/coding_project.dart';
import 'models/coding_run.dart';
import 'models/folder_item.dart';

class CodingApiException implements Exception {
  final int statusCode;
  final String message;

  const CodingApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'CodingApiException($statusCode): $message';
}

class CodingClient {
  final http.Client _client;
  final String _baseUrl;

  CodingClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Projects
  // ============================================================

  Future<List<CodingProject>> listProjects() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/coding/projects'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => CodingProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CodingProject> createProject(Map<String, dynamic> data) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/coding/projects'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    _ensureOk(response);
    return CodingProject.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CodingProject> updateProject(
      int id, Map<String, dynamic> data) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/coding/projects/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    _ensureOk(response);
    return CodingProject.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteProject(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/coding/projects/$id'),
    );
    _ensureOk(response);
  }

  Future<CodingProject> syncProject(int id) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/coding/projects/$id/sync'),
    );
    _ensureOk(response);
    return CodingProject.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============================================================
  // Filesystem
  // ============================================================

  Future<List<FolderItem>> listSubfolders(String? path) async {
    final params = <String, String>{};
    if (path != null && path.isNotEmpty) params['path'] = path;

    final uri = Uri.parse('$_baseUrl/api/v1/coding/fs/subfolders')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => FolderItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // Runs (autonomous)
  // ============================================================

  Future<List<CodingRun>> listRuns({
    int? projectId,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (projectId != null) 'project_id': '$projectId',
    };
    final uri = Uri.parse('$_baseUrl/api/v1/coding/runs')
        .replace(queryParameters: params);
    final response = await _client.get(uri);
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final runs = decoded['runs'] as List<dynamic>? ?? const [];
    return runs
        .map((e) => CodingRun.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CodingRun> getRun(int runId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/coding/runs/$runId'),
    );
    _ensureOk(response);
    return CodingRun.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<CodingRunEvent>> listRunEvents(
    int runId, {
    int afterSeq = 0,
    int limit = 200,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/coding/runs/$runId/events').replace(
      queryParameters: {'after_seq': '$afterSeq', 'limit': '$limit'},
    );
    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => CodingRunEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /coding/runs/{id}/kill` — idempotente do lado do servidor.
  /// `POST /coding/projects/{id}/plan/cancel` → 204. 409 = sem plano ativo.
  Future<void> cancelPlan(int projectId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/coding/projects/$projectId/plan/cancel'),
    );
    _ensureOk(response);
  }

  Future<void> killRun(int runId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/coding/runs/$runId/kill'),
    );
    _ensureOk(response);
  }

  // ============================================================
  // Helpers
  // ============================================================

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        message = decoded['message'] as String? ?? response.body;
      }
    } catch (_) {}
    throw CodingApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }
}
