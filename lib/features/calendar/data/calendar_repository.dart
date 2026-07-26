import 'calendar_client.dart';
import 'models/calendar.dart';
import 'models/calendar_event.dart';

class CalendarRepository {
  final CalendarClient _client;

  CalendarRepository(this._client);

  Future<List<Calendar>> listCalendars() => _client.listCalendars();

  Future<Calendar> createCalendar({
    required String name,
    required String color,
    int? userId,
  }) =>
      _client.createCalendar(name: name, color: color, userId: userId);

  Future<Calendar> updateCalendar(int id, {String? name, String? color}) =>
      _client.updateCalendar(id, name: name, color: color);

  Future<int> deleteCalendar(int id) => _client.deleteCalendar(id);

  Future<List<CalendarEvent>> listEvents({
    required DateTime start,
    required DateTime end,
  }) =>
      _client.listEvents(start: start, end: end);

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
  }) =>
      _client.createEvent(
        calendarId: calendarId,
        title: title,
        notes: notes,
        allDay: allDay,
        occurrenceDate: occurrenceDate,
        startTime: startTime,
        endTime: endTime,
        startDate: startDate,
        endDate: endDate,
        recurrenceType: recurrenceType,
        recurrenceInterval: recurrenceInterval,
        recurrenceDays: recurrenceDays,
        recurrenceEnd: recurrenceEnd,
        reminderMinutesBefore: reminderMinutesBefore,
      );

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
  }) =>
      _client.updateEvent(
        id,
        calendarId: calendarId,
        title: title,
        notes: notes,
        allDay: allDay,
        occurrenceDate: occurrenceDate,
        startTime: startTime,
        clearStartTime: clearStartTime,
        endTime: endTime,
        clearEndTime: clearEndTime,
        startDate: startDate,
        endDate: endDate,
        recurrenceType: recurrenceType,
        clearRecurrence: clearRecurrence,
        recurrenceInterval: recurrenceInterval,
        recurrenceDays: recurrenceDays,
        recurrenceEnd: recurrenceEnd,
        reminderMinutesBefore: reminderMinutesBefore,
        clearReminder: clearReminder,
      );

  Future<void> deleteEvent(int id) => _client.deleteEvent(id);
}
