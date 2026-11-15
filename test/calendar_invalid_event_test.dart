// Evento com fim inválido (fim <= início) não pode esticar a grade: aparece
// no horário de início com a duração mínima visual.
//
// Run:
//   flutter test test/calendar_invalid_event_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/core/utils/event_time_range.dart';
import 'package:bmo_app/features/calendar/data/models/calendar_event.dart';
import 'package:bmo_app/features/calendar/presentation/widgets/calendar_item.dart';
import 'package:bmo_app/features/calendar/presentation/widgets/kalender_events.dart';

CalendarEvent _event({required String start, required String end}) =>
    CalendarEvent(
      id: 1,
      calendarId: 1,
      title: 'Inválido',
      occurrenceDate: DateTime(2026, 8, 24),
      startTime: start,
      endTime: end,
    );

void main() {
  test('fim igual ao início renderiza no início com duração mínima', () {
    final ke = toKalenderEvents([
      EventItem(_event(start: '14:00', end: '14:00')),
    ]).single;

    expect(
      ke.dateTimeRange.start.toUtc(),
      DateTime(2026, 8, 24, 14, 0).toUtc(),
    );
    expect(
      ke.dateTimeRange.end.difference(ke.dateTimeRange.start),
      kMinEventVisualDuration,
    );
  });

  test('fim antes do início não vira bloco de 23 h', () {
    final ke = toKalenderEvents([
      EventItem(_event(start: '14:00', end: '13:00')),
    ]).single;

    expect(
      ke.dateTimeRange.start.toUtc(),
      DateTime(2026, 8, 24, 14, 0).toUtc(),
    );
    expect(
      ke.dateTimeRange.end.difference(ke.dateTimeRange.start),
      kMinEventVisualDuration,
    );
  });
}
