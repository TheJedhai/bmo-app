import 'calendar.dart';

enum RecurrenceType { none, daily, weekly, monthly, yearly }

extension RecurrenceTypeJson on RecurrenceType {
  String toJson() => name;

  static RecurrenceType fromJson(String? value) {
    if (value == null || value == 'none') return RecurrenceType.none;
    return RecurrenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RecurrenceType.none,
    );
  }
}

final class CalendarEvent {
  final int id;
  final int calendarId;
  final String? title;
  final String? notes;
  final bool allDay;
  final DateTime occurrenceDate;
  final String? startTime; // HH:MM
  final String? endTime; // HH:MM
  final DateTime? startDate;
  final DateTime? endDate;
  final RecurrenceType recurrenceType;
  final int recurrenceInterval;
  final List<int> recurrenceDays;
  final DateTime? recurrenceEnd;
  final int? reminderMinutesBefore;
  final bool reminderSent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Calendar? calendar;
  final int? recurrenceParentId;

  const CalendarEvent({
    required this.id,
    required this.calendarId,
    this.title,
    this.notes,
    this.allDay = false,
    required this.occurrenceDate,
    this.startTime,
    this.endTime,
    this.startDate,
    this.endDate,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceInterval = 1,
    this.recurrenceDays = const [],
    this.recurrenceEnd,
    this.reminderMinutesBefore,
    this.reminderSent = false,
    this.createdAt,
    this.updatedAt,
    this.calendar,
    this.recurrenceParentId,
  });

  bool get isRecurring => recurrenceType != RecurrenceType.none;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int? ?? 0,
      calendarId: json['calendar_id'] as int? ?? 0,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
      allDay: json['all_day'] as bool? ?? false,
      occurrenceDate: DateTime.parse(
        json['occurrence_date'] as String? ?? DateTime.now().toIso8601String().split('T').first,
      ),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      startDate: json['start_date'] is String
          ? DateTime.tryParse(json['start_date'] as String)
          : null,
      endDate: json['end_date'] is String
          ? DateTime.tryParse(json['end_date'] as String)
          : null,
      recurrenceType: RecurrenceTypeJson.fromJson(
        json['recurrence_type'] as String?,
      ),
      recurrenceInterval: json['recurrence_interval'] as int? ?? 1,
      recurrenceDays: (json['recurrence_days'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      recurrenceEnd: json['recurrence_end'] is String
          ? DateTime.tryParse(json['recurrence_end'] as String)
          : null,
      reminderMinutesBefore: json['reminder_minutes_before'] as int?,
      reminderSent: json['reminder_sent'] as bool? ?? false,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      calendar: json['calendar'] is Map<String, dynamic>
          ? Calendar.fromJson(json['calendar'] as Map<String, dynamic>)
          : null,
      recurrenceParentId: json['recurrence_parent_id'] as int?,
    );
  }

  @override
  String toString() =>
      'CalendarEvent(id=$id, title="$title", date=$occurrenceDate)';
}
