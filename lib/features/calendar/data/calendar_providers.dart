import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import 'calendar_client.dart';
import 'calendar_repository.dart';
import 'models/calendar.dart';
import 'models/calendar_event.dart';

// ============================================================
// Infraestrutura
// ============================================================

final calendarClientProvider = Provider<CalendarClient>((ref) {
  return CalendarClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(calendarClientProvider));
});

// ============================================================
// Calendars
// ============================================================

class CalendarsNotifier extends AsyncNotifier<List<Calendar>> {
  @override
  Future<List<Calendar>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final repo = ref.watch(calendarRepositoryProvider);
    return repo.listCalendars();
  }

  Future<Calendar?> get defaultCalendar async {
    final calendars = state.valueOrNull ?? await repo.listCalendars();
    return calendars.where((c) => c.isDefault).firstOrNull ?? calendars.firstOrNull;
  }

  CalendarRepository get repo => ref.read(calendarRepositoryProvider);
}

final calendarsProvider =
    AsyncNotifierProvider<CalendarsNotifier, List<Calendar>>(
  CalendarsNotifier.new,
);

// ============================================================
// Events
// ============================================================

typedef MonthRange = ({int year, int month});

class EventsNotifier extends FamilyAsyncNotifier<List<CalendarEvent>, MonthRange> {
  @override
  Future<List<CalendarEvent>> build(MonthRange arg) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final repo = ref.watch(calendarRepositoryProvider);
    final (start, end) = _monthBounds(arg.year, arg.month);
    return repo.listEvents(start: start, end: end);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(calendarRepositoryProvider);
    final (start, end) = _monthBounds(arg.year, arg.month);
    state = await AsyncValue.guard(() => repo.listEvents(start: start, end: end));
  }

  Future<CalendarEvent> create({
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
    final repo = ref.read(calendarRepositoryProvider);
    final event = await repo.createEvent(
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
    final current = state.valueOrNull ?? const <CalendarEvent>[];
    state = AsyncData([...current, event]);
    return event;
  }

  Future<CalendarEvent> edit(
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
    final repo = ref.read(calendarRepositoryProvider);
    final updated = await repo.updateEvent(
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
    // Replace all occurrences of the master event.
    final current = state.valueOrNull ?? const <CalendarEvent>[];
    state = AsyncData([
      for (final e in current)
        if (e.id == id)
          // Keep occurrence_date from each instance, other fields from updated.
          CalendarEvent(
            id: updated.id,
            calendarId: updated.calendarId,
            title: updated.title,
            notes: updated.notes,
            allDay: updated.allDay,
            occurrenceDate: e.occurrenceDate,
            startTime: updated.startTime,
            endTime: updated.endTime,
            startDate: updated.startDate,
            endDate: updated.endDate,
            recurrenceType: updated.recurrenceType,
            recurrenceInterval: updated.recurrenceInterval,
            recurrenceDays: updated.recurrenceDays,
            recurrenceEnd: updated.recurrenceEnd,
            reminderMinutesBefore: updated.reminderMinutesBefore,
            reminderSent: updated.reminderSent,
            createdAt: updated.createdAt,
            updatedAt: updated.updatedAt,
            calendar: updated.calendar ?? e.calendar,
          )
        else
          e,
    ]);
    return updated;
  }

  Future<void> delete(int id) async {
    final repo = ref.read(calendarRepositoryProvider);
    await repo.deleteEvent(id);
    final current = state.valueOrNull ?? const <CalendarEvent>[];
    state = AsyncData(current.where((e) => e.id != id).toList());
  }

  (DateTime, DateTime) _monthBounds(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    return (start, end);
  }
}

final eventsProvider = AsyncNotifierProvider.family<
    EventsNotifier, List<CalendarEvent>, MonthRange>(
  EventsNotifier.new,
);

// ============================================================
// Visible month (shared between AgendaScreen and MonthView)
// ============================================================

final visibleMonthProvider = StateProvider<MonthRange>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

// ============================================================
// Upcoming events (dashboard card + agenda view)
// ============================================================

final upcomingEventsProvider = FutureProvider.autoDispose
    .family<List<CalendarEvent>, int>((ref, limit) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final repo = ref.watch(calendarRepositoryProvider);
  final now = DateTime.now();
  // 365 days keeps us safely under backend's 370-day range limit.
  final end = now.add(const Duration(days: 365));
  final all = await repo.listEvents(start: now, end: end);
  // Backend returns events sorted by (occurrence_date, start_time, id).
  // Dart sort is not stable, so trusting backend order preserves intra-day ordering.
  return all.take(limit).toList();
});
