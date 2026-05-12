import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/folder.dart';
import 'models/task.dart';

class MissionsApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const MissionsApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() => 'MissionsApiException($statusCode, $errorCode): $message';
}

class MissionsClient {
  final http.Client _client;
  final String _baseUrl;

  MissionsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Folders
  // ============================================================

  Future<List<Folder>> listFolders() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/folders'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Folder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Folder> createFolder({
    required String name,
    int sortOrder = 0,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/folders'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'sort_order': sortOrder}),
    );
    _ensureOk(response);
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Folder> updateFolder(
    int id, {
    String? name,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (sortOrder != null) body['sort_order'] = sortOrder;

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/folders/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Folder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ============================================================
  // Tasks
  // ============================================================

  Future<List<Task>> listTasks({
    String? status,
    int? folderId,
    int? parentId,
    DateTime? dueBefore,
    DateTime? dueAfter,
    bool includeSubtasks = false,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (folderId != null) queryParams['folder_id'] = folderId.toString();
    if (parentId != null) queryParams['parent_id'] = parentId.toString();
    if (dueBefore != null) queryParams['due_before'] = _formatDate(dueBefore);
    if (dueAfter != null) queryParams['due_after'] = _formatDate(dueAfter);
    if (includeSubtasks) queryParams['include_subtasks'] = 'true';

    final uri = Uri.parse('$_baseUrl/api/v1/tasks')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Task> getTask(int id) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/tasks/$id'),
    );
    _ensureOk(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Task> createTask({
    required String title,
    required int folderId,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? parentId,
    TaskStatus? status,
    int? priority,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'folder_id': folderId,
    };
    if (notes != null) body['notes'] = notes;
    if (dueDate != null) body['due_date'] = _formatDate(dueDate);
    if (dueTime != null) body['due_time'] = dueTime;
    if (recurrenceType != null) {
      body['recurrence_type'] = recurrenceType.toJson();
    }
    if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
    if (parentId != null) body['parent_id'] = parentId;
    if (status != null) body['status'] = status.toJson();
    if (priority != null) body['priority'] = priority;
    if (sortOrder != null) body['sort_order'] = sortOrder;

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Task> updateTask(
    int id, {
    String? title,
    String? notes,
    DateTime? dueDate,
    String? dueTime,
    RecurrenceType? recurrenceType,
    List<int>? recurrenceDays,
    int? folderId,
    int? parentId,
    TaskStatus? status,
    int? priority,
    int? sortOrder,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (notes != null) body['notes'] = notes;
    if (dueDate != null) body['due_date'] = _formatDate(dueDate);
    if (dueTime != null) body['due_time'] = dueTime;
    if (recurrenceType != null) {
      body['recurrence_type'] = recurrenceType.toJson();
    }
    if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
    if (folderId != null) body['folder_id'] = folderId;
    if (parentId != null) body['parent_id'] = parentId;
    if (status != null) body['status'] = status.toJson();
    if (priority != null) body['priority'] = priority;
    if (sortOrder != null) body['sort_order'] = sortOrder;

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/tasks/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return Task.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<({Task completed, Task? nextOccurrence})> completeTask(int id) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/tasks/$id/complete'),
      headers: {'Content-Type': 'application/json'},
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      completed: Task.fromJson(decoded['completed'] as Map<String, dynamic>),
      nextOccurrence: decoded['next_occurrence'] != null
          ? Task.fromJson(decoded['next_occurrence'] as Map<String, dynamic>)
          : null,
    );
  }

  Future<({int deletedId, int cascadedSubtasks})> deleteTask(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/tasks/$id'),
    );
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      deletedId: decoded['deleted_id'] as int? ?? id,
      cascadedSubtasks: decoded['cascaded_subtasks'] as int? ?? 0,
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

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
    throw MissionsApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
