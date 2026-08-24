import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../../../features/missions/data/missions_providers.dart';
import '../../../features/missions/data/models/task.dart';
import 'calendar_client.dart';
import 'calendar_repository.dart';
import 'calendar_visibility_provider.dart';
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

  Future<Calendar> create({
    required String name,
    required String color,
    required bool personal,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    final cal = await repo.createCalendar(
      name: name,
      color: color,
      userId: personal ? userId : null,
    );
    final current = state.valueOrNull ?? const <Calendar>[];
    state = AsyncData([...current, cal]);
    return cal;
  }

  Future<Calendar> updateCalendar(
    int id, {
    String? name,
    String? color,
  }) async {
    final cal = await repo.updateCalendar(id, name: name, color: color);
    final current = state.valueOrNull ?? const <Calendar>[];
    state = AsyncData([
      for (final c in current)
        if (c.id == id) cal else c,
    ]);
    return cal;
  }

  Future<int> delete(int id) async {
    final moved = await repo.deleteCalendar(id);
    final current = state.valueOrNull ?? const <Calendar>[];
    state = AsyncData(current.where((c) => c.id != id).toList());
    return moved;
  }
}

final calendarsProvider =
    AsyncNotifierProvider<CalendarsNotifier, List<Calendar>>(
  CalendarsNotifier.new,
);

/// Indexed lookup: calendar id → Calendar.
/// Used at render time so color/name changes reflect immediately without re-fetch.
final calendarsByIdProvider = Provider<Map<int, Calendar>>((ref) {
  final calendars = ref.watch(calendarsProvider).valueOrNull ?? const [];
  return {for (final c in calendars) c.id: c};
});

// ============================================================
// Events
// ============================================================

typedef MonthRange = ({int year, int month});

/// Quantos dias além do mês cada busca cobre.
///
/// A chave da family é o mês, mas a unidade renderizada é a semana (ou o
/// grid do mês com dias adjacentes do mês anterior/seguinte visíveis). Nas
/// viradas de mês esses dois conjuntos não coincidem: uma semana de
/// 30/08 a 05/09 é atribuída a setembro, mas exibe (e precisa buscar)
/// eventos de 31/08. Cobertura de 7 dias de cada lado cobre o pior caso
/// da semana que cruza a virada e dos dias adjacentes do grid. Manter a
/// chave mensal (em vez de trocar para DateTimeRange) preserva o cache por
/// página — trocar causaria refetch a cada swipe.
const int _searchPaddingDays = 7;

/// Janela de busca de eventos/tasks para um [MonthRange]: o mês alargado em
/// [_searchPaddingDays] para cada lado. Ponto único usado por EventsNotifier
/// e CalendarTasksNotifier — não repetir a aritmética em cada notifier.
(DateTime, DateTime) _searchWindow(MonthRange arg) {
  final first = DateTime(arg.year, arg.month, 1);
  final last = DateTime(arg.year, arg.month + 1, 0);
  return (
    first.subtract(const Duration(days: _searchPaddingDays)),
    last.add(const Duration(days: _searchPaddingDays)),
  );
}

class EventsNotifier extends FamilyAsyncNotifier<List<CalendarEvent>, MonthRange> {
  @override
  Future<List<CalendarEvent>> build(MonthRange arg) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final repo = ref.watch(calendarRepositoryProvider);
    final (start, end) = _searchWindow(arg);
    return repo.listEvents(start: start, end: end);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(calendarRepositoryProvider);
    final (start, end) = _searchWindow(arg);
    state = await AsyncValue.guard(() async {
      final events = await repo.listEvents(start: start, end: end);
      return events;
    });
  }
}

final eventsProvider = AsyncNotifierProvider.family<
    EventsNotifier, List<CalendarEvent>, MonthRange>(
  EventsNotifier.new,
);

// ============================================================
// Tasks (missions) for calendar merge
// ============================================================

class CalendarTasksNotifier
    extends FamilyAsyncNotifier<List<Task>, MonthRange> {
  @override
  Future<List<Task>> build(MonthRange arg) async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final repo = ref.watch(missionsRepositoryProvider);
    final (dueAfter, dueBefore) = _searchWindow(arg);
    return repo.listTasks(
      status: 'pending',
      dueAfter: dueAfter,
      dueBefore: dueBefore,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final repo = ref.read(missionsRepositoryProvider);
    final (dueAfter, dueBefore) = _searchWindow(arg);
    state = await AsyncValue.guard(() => repo.listTasks(
          status: 'pending',
          dueAfter: dueAfter,
          dueBefore: dueBefore,
        ));
  }
}

final calendarTasksProvider = AsyncNotifierProvider.family<
    CalendarTasksNotifier, List<Task>, MonthRange>(
  CalendarTasksNotifier.new,
);

// ============================================================
// Visible month (shared between CalendarScreen and MonthView)
// ============================================================

final visibleMonthProvider = StateProvider<MonthRange>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

/// The ID of the currently selected calendar event (kalender-level selection).
///
/// Updated by MonthView whenever [CalendarController.selectedEvent] changes.
/// Read by tile builders to render a selected-state highlight.
final selectedEventIdProvider = StateProvider<String?>((ref) => null);

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
  final events = await repo.listEvents(start: now, end: end);
  // Backend returns events sorted by (occurrence_date, start_time, id).
  // Dart sort is not stable, so trusting backend order preserves intra-day ordering.
  final hiddenCalendarIds = ref.watch(calendarVisibilityProvider);
  return filterVisibleEvents(events, hiddenCalendarIds).take(limit).toList();
});
