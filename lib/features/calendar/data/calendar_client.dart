import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/calendar.dart';
import 'models/calendar_event.dart';

class CalendarApiException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;

  const CalendarApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  @override
  String toString() =>
      'CalendarApiException($statusCode, $errorCode): $message';
}

class CalendarClient {
  final http.Client _client;
  final String _baseUrl;

  CalendarClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // -----------------------------------------------------------
  // Calendars
  // -----------------------------------------------------------

  Future<List<Calendar>> listCalendars() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v1/calendars'),
    );
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Calendar.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -----------------------------------------------------------
  // Events
  // -----------------------------------------------------------

  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/events').replace(
      queryParameters: {
        'start': _formatDate(start),
        'end': _formatDate(end),
      },
    );
    final response = await _client.get(uri);
    _ensureOk(response);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent({
    required int calendarId,
    String? title,
    String? notes,
    bool allDay = false,
    required String occurrenceDate,
    String? startTime,
    String? endTime,
    String? startDate,
    String? endDate,
    String? recurrenceType,
    int recurrenceInterval = 1,
    List<int> recurrenceDays = const [],
    String? recurrenceEnd,
    int? reminderMinutesBefore,
  }) async {
    final body = <String, dynamic>{
      'calendar_id': calendarId,
      'occurrence_date': occurrenceDate,
      'all_day': allDay,
    };
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (startTime != null) body['start_time'] = startTime;
    if (endTime != null) body['end_time'] = endTime;
    if (startDate != null) body['start_date'] = startDate;
    if (endDate != null) body['end_date'] = endDate;
    if (recurrenceType != null && recurrenceType != 'none') {
      body['recurrence_type'] = recurrenceType;
      body['recurrence_interval'] = recurrenceInterval;
      if (recurrenceDays.isNotEmpty) {
        body['recurrence_days'] = recurrenceDays;
      }
      if (recurrenceEnd != null) body['recurrence_end'] = recurrenceEnd;
    }
    if (reminderMinutesBefore != null) {
      body['reminder_minutes_before'] = reminderMinutesBefore;
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return CalendarEvent.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CalendarEvent> updateEvent(
    int id, {
    int? calendarId,
    String? title,
    String? notes,
    bool? allDay,
    String? occurrenceDate,
    String? startTime,
    bool clearStartTime = false,
    String? endTime,
    bool clearEndTime = false,
    String? startDate,
    String? endDate,
    String? recurrenceType,
    bool clearRecurrence = false,
    int? recurrenceInterval,
    List<int>? recurrenceDays,
    String? recurrenceEnd,
    int? reminderMinutesBefore,
    bool clearReminder = false,
  }) async {
    final body = <String, dynamic>{};
    if (calendarId != null) body['calendar_id'] = calendarId;
    if (title != null) body['title'] = title;
    if (notes != null) body['notes'] = notes;
    if (allDay != null) body['all_day'] = allDay;
    if (occurrenceDate != null) body['occurrence_date'] = occurrenceDate;

    if (startTime != null) {
      body['start_time'] = startTime;
    } else if (clearStartTime) {
      body['start_time'] = null;
    }
    if (endTime != null) {
      body['end_time'] = endTime;
    } else if (clearEndTime) {
      body['end_time'] = null;
    }

    if (startDate != null) body['start_date'] = startDate;
    if (endDate != null) body['end_date'] = endDate;

    if (clearRecurrence) {
      body['recurrence_type'] = null;
      body['recurrence_days'] = null;
      body['recurrence_interval'] = null;
      body['recurrence_end'] = null;
    } else if (recurrenceType != null) {
      body['recurrence_type'] = recurrenceType;
      body['recurrence_interval'] = recurrenceInterval ?? 1;
      if (recurrenceDays != null) body['recurrence_days'] = recurrenceDays;
      if (recurrenceEnd != null) body['recurrence_end'] = recurrenceEnd;
    }

    if (clearReminder) {
      body['reminder_minutes_before'] = null;
    } else if (reminderMinutesBefore != null) {
      body['reminder_minutes_before'] = reminderMinutesBefore;
    }

    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v1/events/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _ensureOk(response);
    return CalendarEvent.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteEvent(int id) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v1/events/$id'),
    );
    _ensureOk(response);
  }

  // -----------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------

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
    } catch (_) {}
    throw CalendarApiException(
      statusCode: response.statusCode,
      errorCode: errorCode,
      message: message,
    );
  }
}

String _formatDate(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
