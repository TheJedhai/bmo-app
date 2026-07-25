import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import '../../data/models/calendar_event.dart' as app;

/// Wraps our [app.CalendarEvent] model so it can be rendered by kalender.
class KalenderCalendarEvent extends CalendarEvent {
  final app.CalendarEvent source;

  KalenderCalendarEvent({
    required super.dateTimeRange,
    required this.source,
  }) : super(id: '${source.id}_${source.occurrenceDate}');

  Color get color {
    final hex = source.calendar?.color ?? '#8BC9A3';
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF8BC9A3);
  }

  @override
  bool operator ==(Object other) =>
      super == other && other is KalenderCalendarEvent && other.id == id;

  @override
  int get hashCode => Object.hash(super.hashCode, id);
}

/// Converts a list of app [app.CalendarEvent]s to kalender events.
List<KalenderCalendarEvent> toKalenderEvents(List<app.CalendarEvent> events) {
  return events.map((e) {
    final startDate = e.occurrenceDate;
    final endDate = e.occurrenceDate.add(const Duration(days: 1));

    DateTime start;
    DateTime end;

    if (!e.allDay && e.startTime != null && e.endTime != null) {
      final startParts = e.startTime!.split(':');
      final endParts = e.endTime!.split(':');
      start = DateTime(
        startDate.year, startDate.month, startDate.day,
        int.tryParse(startParts[0]) ?? 0,
        int.tryParse(startParts[1]) ?? 0,
      );
      end = DateTime(
        endDate.year, endDate.month, endDate.day,
        int.tryParse(endParts[0]) ?? 0,
        int.tryParse(endParts[1]) ?? 0,
      );
    } else {
      start = DateTime(startDate.year, startDate.month, startDate.day);
      end = DateTime(endDate.year, endDate.month, endDate.day);
    }

    return KalenderCalendarEvent(
      dateTimeRange: DateTimeRange(start: start, end: end),
      source: e,
    );
  }).toList();
}
