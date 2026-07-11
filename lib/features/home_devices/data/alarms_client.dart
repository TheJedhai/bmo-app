import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_alarm.dart';
import 'scene.dart';

class AlarmsApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const AlarmsApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'AlarmsApiException($statusCode, $errorCode): $message';
}

class AlarmsClient {
  final http.Client _client;
  final String _baseUrl;

  AlarmsClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  Future<List<DeviceAlarm>> list() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/alarms'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => DeviceAlarm.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceAlarm> create({
    required String name,
    required String dueDate,
    required String dueTime,
    String? recurrenceType,
    List<int>? recurrenceDays,
    required String actionType,
    String? deviceName,
    String? targetState,
    int? sceneId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'due_date': dueDate,
      'due_time': dueTime,
      'action_type': actionType,
    };
    if (recurrenceType != null) body['recurrence_type'] = recurrenceType;
    if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
    if (deviceName != null) body['device_name'] = deviceName;
    if (targetState != null) body['target_state'] = targetState;
    if (sceneId != null) body['scene_id'] = sceneId;

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/alarms'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return DeviceAlarm.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DeviceAlarm> update(
    int id, {
    String? name,
    bool? enabled,
    String? dueDate,
    String? dueTime,
    String? recurrenceType,
    List<int>? recurrenceDays,
    bool clearRecurrence = false,
    String? actionType,
    String? deviceName,
    bool clearDeviceName = false,
    String? targetState,
    bool clearTargetState = false,
    int? sceneId,
    bool clearSceneId = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (enabled != null) body['enabled'] = enabled;
    if (dueDate != null) body['due_date'] = dueDate;
    if (dueTime != null) body['due_time'] = dueTime;

    if (clearRecurrence) {
      body['recurrence_type'] = null;
      body['recurrence_days'] = null;
    } else {
      if (recurrenceType != null) body['recurrence_type'] = recurrenceType;
      if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
    }

    if (actionType != null) body['action_type'] = actionType;
    if (clearDeviceName) {
      body['device_name'] = null;
    } else if (deviceName != null) {
      body['device_name'] = deviceName;
    }
    if (clearTargetState) {
      body['target_state'] = null;
    } else if (targetState != null) {
      body['target_state'] = targetState;
    }
    if (clearSceneId) {
      body['scene_id'] = null;
    } else if (sceneId != null) {
      body['scene_id'] = sceneId;
    }

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/alarms/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return DeviceAlarm.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/alarms/$id'),
    );
    _ensureOk(response);
  }

  Future<List<Scene>> listScenes() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/scenes'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Scene.fromJson(e as Map<String, dynamic>))
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
    throw AlarmsApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}
