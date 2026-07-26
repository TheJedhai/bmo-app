import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/models/calendar_event.dart' as app;

/// Wraps our [app.CalendarEvent] model so it can be rendered by kalender.
class KalenderCalendarEvent extends CalendarEvent {
  final app.CalendarEvent source;

  KalenderCalendarEvent({
    required super.dateTimeRange,
    required this.source,
  }) : super(id: '${source.id}_${source.occurrenceDate.toIso8601String()}');

  String get title => source.title ?? '(sem título)';
  bool get allDay => source.allDay;
  String? get startTime => source.startTime;
  String? get endTime => source.endTime;

  Color get calendarColor {
    final hex = source.calendar?.color ?? '#8BC9A3';
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF8BC9A3);
  }

  String get calendarName => source.calendar?.name ?? '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KalenderCalendarEvent &&
          other.id == id &&
          other.start == start &&
          other.end == end &&
          other.source.title == source.title &&
          other.source.allDay == source.allDay &&
          other.source.startTime == source.startTime &&
          other.source.endTime == source.endTime &&
          other.source.calendar?.color == source.calendar?.color);

  @override
  int get hashCode => Object.hash(
        id,
        start,
        end,
        source.title,
        source.allDay,
        source.startTime,
        source.endTime,
        source.calendar?.color,
      );

}

/// Converts a list of app [app.CalendarEvent]s to kalender events.
List<KalenderCalendarEvent> toKalenderEvents(List<app.CalendarEvent> events) {
  return events.map((e) {
    final startDate = e.occurrenceDate;

    DateTime start;
    DateTime end;

    if (!e.allDay && e.startTime != null && e.endTime != null) {
      final startParts = e.startTime!.split(':');
      final endParts = e.endTime!.split(':');
      start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        int.tryParse(startParts[0]) ?? 0,
        int.tryParse(startParts[1]) ?? 0,
      );
      end = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        int.tryParse(endParts[0]) ?? 0,
        int.tryParse(endParts[1]) ?? 0,
      );
    } else {
      start = DateTime(startDate.year, startDate.month, startDate.day);
      end = DateTime(startDate.year, startDate.month, startDate.day + 1);
    }

    return KalenderCalendarEvent(
      dateTimeRange: DateTimeRange(start: start, end: end),
      source: e,
    );
  }).toList();
}

/// Strips seconds from a "HH:mm:ss" time string, returning "HH:mm".
/// Passes through strings that are already "HH:mm".
String _formatTime(String time) {
  final parts = time.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return time;
}

/// Builds an event tile for the month view.
///
/// All-day: filled chip with calendar color, no time label.
/// Timed: subtle background (color at low opacity) + left color bar + time label.
Widget kalenderMonthTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  final ke = event as KalenderCalendarEvent;
  final color = ke.calendarColor;
  final isAllDay = ke.allDay;

  if (isAllDay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        ke.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BmoColors.screenBg,
        ),
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(3),
      border: Border(
        left: BorderSide(color: color, width: 3),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, top: 1, bottom: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ke.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          if (ke.startTime != null)
            Text(
              _formatTime(ke.startTime!),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: BmoColors.textMuted,
              ),
            ),
        ],
      ),
    ),
  );
}
