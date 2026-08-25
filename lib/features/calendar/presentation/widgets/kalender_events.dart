import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../../../core/utils/event_time_range.dart';
import '../../../missions/data/missions_providers.dart';
import '../../../missions/data/models/task.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart' as app;
import 'calendar_item.dart';

/// Wraps a [CalendarItem] so it can be rendered by kalender.
class KalenderCalendarEvent extends CalendarEvent {
  final CalendarItem source;

  KalenderCalendarEvent({
    required super.dateTimeRange,
    required this.source,
    EventInteraction? interaction,
  }) : super(
          id: switch (source) {
            EventItem(event: final e) =>
              'event_${e.id}_${e.occurrenceDate.toIso8601String()}',
            TaskItem(task: final t) => 'task_${t.id}',
          },
          interaction: interaction ?? _defaultInteraction(source),
        );

  static EventInteraction _defaultInteraction(CalendarItem source) => switch (source) {
    EventItem() => EventInteraction.allowAll(),
    TaskItem() => EventInteraction(
        allowStartResize: false,
        allowEndResize: false,
        allowRescheduling: true,
      ),
  };

  /// Creates a provisional event shown during drag-to-create.
  ///
  /// The dummy [source] has id=-1 and calendarId=-1 so it never matches a real
  /// event or calendar. It is NOT added to the EventsController — kalender
  /// renders it from the controller's newEvent/selectedEvent while the gesture
  /// is active, and clears it when the drag ends or is cancelled.
  factory KalenderCalendarEvent.provisional({
    required DateTimeRange dateTimeRange,
  }) {
    final dummySource = app.CalendarEvent(
      id: -1,
      calendarId: -1,
      title: 'Novo evento',
      occurrenceDate: dateTimeRange.start,
    );
    return KalenderCalendarEvent(
      dateTimeRange: dateTimeRange,
      source: EventItem(dummySource),
      interaction: EventInteraction.allowAll(),
    );
  }

  String get title => switch (source) {
    EventItem(:final event) => event.title ?? '(sem título)',
    TaskItem(:final task) => task.title,
  };

  bool get allDay => switch (source) {
    EventItem(:final event) => event.allDay,
    // Atrasadas viram dia inteiro mesmo com horário — o horário de vencimento
    // original perdeu o sentido no dia de hoje (decisão de produto).
    TaskItem(:final task) => task.isOverdue || task.dueTime == null,
  };

  String? get startTime => switch (source) {
    EventItem(:final event) => event.startTime,
    TaskItem(:final task) => task.isOverdue ? null : task.dueTime,
  };

  /// Tarefa atrasada (pendente vencida antes de hoje). Usado para posicionar
  /// no dia de hoje e para destacar a pílula em vermelho.
  bool get isOverdueTask => switch (source) {
    TaskItem(:final task) => task.isOverdue,
    _ => false,
  };

  String? get endTime => switch (source) {
    EventItem(:final event) => event.endTime,
    TaskItem() => null,
  };

  /// Returns a [KalenderCalendarEvent] copy with the given fields replaced.
  ///
  /// Preserves [source] and all custom fields. Carries the existing [id]
  /// over — required by kalender so selection/layout lookups keep working.
  @override
  KalenderCalendarEvent copyWith({
    DateTimeRange? dateTimeRange,
    EventInteraction? interaction,
  }) {
    return KalenderCalendarEvent(
      dateTimeRange: dateTimeRange ?? this.dateTimeRange,
      source: source,
      interaction: interaction ?? this.interaction,
    )..id = id;
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is KalenderCalendarEvent &&
      other.title == title &&
      other.allDay == allDay &&
      other.startTime == startTime &&
      other.endTime == endTime;

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        title,
        allDay,
        startTime,
        endTime,
      );

}

/// Converts a list of [CalendarItem]s to kalender events.
List<KalenderCalendarEvent> toKalenderEvents(List<CalendarItem> items) {
  return items.map((item) => switch (item) {
    EventItem(:final event) => _toKalenderEvent(event),
    TaskItem(:final task) => _toKalenderTaskEvent(task),
  }).toList();
}

KalenderCalendarEvent _toKalenderEvent(app.CalendarEvent e) {
  final startDate = e.occurrenceDate;

  DateTime start;
  DateTime end;

  if (!e.allDay && e.startTime != null && e.endTime != null) {
    // Regra de produto: se end_time for anterior a start_time, o evento
    // termina no dia seguinte. Ver timeRangeOnDay (ponto único da convenção).
    final range = timeRangeOnDay(startDate, e.startTime!, e.endTime!);
    start = range.start;
    end = range.end;
  } else {
    start = DateTime(startDate.year, startDate.month, startDate.day);
    end = DateTime(startDate.year, startDate.month, startDate.day + 1);
  }

  return KalenderCalendarEvent(
    dateTimeRange: DateTimeRange(start: start, end: end),
    source: EventItem(e),
  );
}

KalenderCalendarEvent _toKalenderTaskEvent(Task t) {
  // Atrasadas rolam para HOJE, na faixa de dia inteiro, e nunca aparecem na
  // data original. Regra espelha o widget iOS (endpoint /api/v1/widget/calendar)
  // e o card de Missões da dashboard. O horário de vencimento original é
  // descartado no dia de hoje — decreto que o horário perdeu o sentido.
  final overdue = t.isOverdue;
  final baseDate = overdue ? DateTime.now() : t.dueDate!;
  DateTime start;
  DateTime end;

  if (!overdue && t.dueTime != null) {
    final parts = t.dueTime!.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    start = DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    // Nominal 30 min duration for layout only — never persisted.
    end = start.add(const Duration(minutes: 30));
  } else {
    start = DateTime(baseDate.year, baseDate.month, baseDate.day);
    end = DateTime(baseDate.year, baseDate.month, baseDate.day + 1);
  }

  return KalenderCalendarEvent(
    dateTimeRange: DateTimeRange(start: start, end: end),
    source: TaskItem(t),
  );
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
/// Wrapped in [Consumer] so calendar color/name changes reflect immediately
/// without re-fetching events. When selected, renders a transparent
/// hit-testable placeholder so the dropTargetTile overlay is the only
/// visible layer.
Widget kalenderMonthTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  final ke = event as KalenderCalendarEvent;
  return switch (ke.source) {
    EventItem(event: final e) => Consumer(
      builder: (context, ref, _) {
        final calendarsById = ref.watch(calendarsByIdProvider);
        final selectedId = ref.watch(selectedEventIdProvider);
        return _buildEventMonthTile(ke, e, calendarsById,
            isSelected: selectedId == ke.id);
      },
    ),
    TaskItem(task: final t) => Consumer(
      builder: (context, ref, _) {
        final selectedId = ref.watch(selectedEventIdProvider);
        return _buildTaskMonthTile(ke, t,
            isSelected: selectedId == ke.id);
      },
    ),
  };
}

Widget _buildEventMonthTile(
  KalenderCalendarEvent ke,
  app.CalendarEvent e,
  Map<int, dynamic> calendarsById, {
  bool isSelected = false,
}) {
  if (isSelected) {
    return const ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }

  final calendar = calendarsById[e.calendarId];
  final color = _hexToColor(calendar?.color ?? '#8BC9A3');
  final isAllDay = e.allDay;

  if (isAllDay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
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
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
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
                  if (e.isRecurring || e.recurrenceParentId != null)
                    _buildRecurrenceIcon(e, BmoColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTaskMonthTile(
  KalenderCalendarEvent ke,
  Task t, {
  bool isSelected = false,
}) {
  if (isSelected) {
    return const ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }

  final color = _taskColor(ke);

  if (ke.allDay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TaskCheckbox(t),
          const SizedBox(width: 4),
          Expanded(
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
          ),
          if (t.recurrenceType != null)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(Icons.repeat, size: 10, color: BmoColors.screenBg.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, top: 1, bottom: 1),
              child: Row(
                children: [
                  _TaskCheckbox(t),
                  const SizedBox(width: 4),
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
                  if (t.recurrenceType != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(Icons.repeat, size: 10, color: BmoColors.textMuted.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Circular checkbox for mission tiles (Apple Reminders style).
///
/// Tapping completes the task via the missions API and refreshes the calendar.
class _TaskCheckbox extends ConsumerWidget {
  final Task task;
  const _TaskCheckbox(this.task);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _completeTask(context, ref),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: BmoColors.textPrimary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Future<void> _completeTask(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(missionsRepositoryProvider);
      await repo.completeTask(task.id);
      // Refresh tasks for current visible month.
      final monthRange = ref.read(visibleMonthProvider);
      ref.read(calendarTasksProvider(monthRange).notifier).refresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao concluir missão: $e'),
            backgroundColor: BmoColors.accentRed,
          ),
        );
      }
    }
  }
}

// ponytail: global lock on task completion — one at a time is fine,
// add debounce if double-tap becomes an issue.

/// Builds an event tile for multi-day views (week/day body).
///
/// Shows title and time; in short tiles, only title with ellipsis.
/// Wrapped in [Consumer] so calendar color changes reflect immediately.
Widget kalenderMultiDayTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  if (event is! KalenderCalendarEvent) {
    return Container(
      color: const Color(0xFF8BC9A3),
      child: const Text('novo', style: TextStyle(color: Color(0xFF1E1F23))),
    );
  }
  final ke = event;
  return switch (ke.source) {
    EventItem(event: final e) => Consumer(
      builder: (context, ref, _) {
        final calendarsById = ref.watch(calendarsByIdProvider);
        final selectedId = ref.watch(selectedEventIdProvider);
        return _buildEventMultiDayTile(ke, e, calendarsById,
            isSelected: selectedId == ke.id);
      },
    ),
    TaskItem(task: final t) => Consumer(
      builder: (context, ref, _) {
        final selectedId = ref.watch(selectedEventIdProvider);
        return _buildTaskMultiDayTile(ke, t,
            isSelected: selectedId == ke.id);
      },
    ),
  };
}

Widget _buildEventMultiDayTile(
  KalenderCalendarEvent ke,
  app.CalendarEvent e,
  Map<int, dynamic> calendarsById, {
  bool isSelected = false,
}) {
  // When selected, the normal tile is invisible (but hit-testable).
  // The kalenderDropTargetTile overlay renders the full selected style on top.
  if (isSelected) {
    return const ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }

  final calendar = calendarsById[e.calendarId];
  final color = _hexToColor(calendar?.color ?? '#8BC9A3');
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: isShort
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
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
                        if (e.isRecurring || e.recurrenceParentId != null)
                          _buildRecurrenceIcon(e, BmoColors.textMuted),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                ke.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: BmoColors.textPrimary,
                                ),
                              ),
                            ),
                            if (e.isRecurring || e.recurrenceParentId != null)
                              _buildRecurrenceIcon(e, BmoColors.textMuted),
                          ],
                        ),
                        if (ke.startTime != null)
                          Text(
                            ke.endTime != null
                                ? '${_formatTime(ke.startTime!)}–${_formatTime(ke.endTime!)}'
                                : _formatTime(ke.startTime!),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              color: BmoColors.textMuted,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTaskMultiDayTile(
  KalenderCalendarEvent ke,
  Task t, {
  bool isSelected = false,
}) {
  // When selected, the normal tile is invisible (but hit-testable).
  // The kalenderDropTargetTile overlay renders the full selected style on top.
  if (isSelected) {
    return const ColoredBox(
      color: Colors.transparent,
      child: SizedBox.expand(),
    );
  }

  final color = _taskColor(ke);
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: isShort
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TaskCheckbox(t),
                        const SizedBox(width: 4),
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
                        if (t.recurrenceType != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(Icons.repeat, size: 10, color: BmoColors.textMuted.withValues(alpha: 0.5)),
                          ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TaskCheckbox(t),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ke.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: BmoColors.textPrimary,
                                ),
                              ),
                            ),
                            if (t.recurrenceType != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Icon(Icons.repeat, size: 10, color: BmoColors.textMuted.withValues(alpha: 0.5)),
                              ),
                          ],
                        ),
                        if (ke.startTime != null)
                          Text(
                            _formatTime(ke.startTime!),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              color: BmoColors.textMuted,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds an all-day event tile for the multi-day header.
///
/// Same visual language as the month view all-day chips: solid color with
/// calendar accent, white text. Wrapped in [Consumer] so calendar color
/// changes reflect immediately.
Widget kalenderAllDayTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  final ke = event as KalenderCalendarEvent;
  return Consumer(
    builder: (context, ref, _) {
      final calendarsById = ref.watch(calendarsByIdProvider);
      final selectedId = ref.watch(selectedEventIdProvider);

      return switch (ke.source) {
        EventItem(event: final e) => _buildEventAllDayTile(ke, e, calendarsById,
            isSelected: selectedId == ke.id),
        TaskItem(task: final t) => _buildTaskAllDayTile(ke, t,
            isSelected: selectedId == ke.id),
      };
    },
  );
}

Widget _buildEventAllDayTile(
  KalenderCalendarEvent ke,
  app.CalendarEvent e,
  Map<int, dynamic> calendarsById, {
  bool isSelected = false,
}) {
  final calendar = calendarsById[e.calendarId];
  final color = _hexToColor(calendar?.color ?? '#8BC9A3');

  if (isSelected) {
    return ClipRect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  return ClipRect(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
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
    ),
  );
}

Widget _buildTaskAllDayTile(KalenderCalendarEvent ke, Task t, {bool isSelected = false}) {
  final color = _taskColor(ke);

  if (isSelected) {
    return ClipRect(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TaskCheckbox(t),
                      const SizedBox(width: 4),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return ClipRect(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TaskCheckbox(t),
          const SizedBox(width: 4),
          Expanded(
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
          ),
          if (t.recurrenceType != null)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Icon(Icons.repeat, size: 10, color: BmoColors.screenBg.withValues(alpha: 0.7)),
            ),
        ],
      ),
    ),
  );
}

/// Builds the recurrence/override icon for an event tile.
///
/// Normal recurring events show [Icons.repeat]. Override occurrences
/// (individually modified with scope=this) show [Icons.repeat_one] and a
/// slightly different color so they are distinguishable from the rest of
/// the series.
Widget _buildRecurrenceIcon(app.CalendarEvent e, Color color) {
  final isOverride = e.recurrenceParentId != null;
  return Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Icon(
      isOverride ? Icons.repeat_one : Icons.repeat,
      size: 10,
      color: isOverride ? color : color.withValues(alpha: 0.5),
    ),
  );
}

/// Cor da pílula de tarefa no calendário. Atrasadas (vencidas antes de hoje)
/// usam o vermelho de destaque do tema — mesmo caso do widget iOS — para se
/// separar visualmente das demais; as demais usam o âmbar [BmoColors.taskChipColor].
Color _taskColor(KalenderCalendarEvent ke) =>
    ke.isOverdueTask ? BmoColors.accentRed : BmoColors.taskChipColor;

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return const Color(0xFF8BC9A3);
}

// ---------------------------------------------------------------------------
// Drag/drop builders — called by TileComponents during drag-to-create and
// drag-to-reschedule.
//
// • dropTargetTile: renders the in-place tile for the selected/new event in
//   the DayDropTargetColumn overlay. This is THE builder for provisional
//   events during drag-to-create.
// • tileWhenDraggingBuilder: renders the tile at the original position while
//   an existing event is being dragged.
// • feedbackTileBuilder: renders the tile that follows the pointer during
//   drag of an existing event.
// ---------------------------------------------------------------------------

/// Renders the drop-target / provisional-event tile in the multi-day body.
///
/// During drag-to-create this draws the in-place block that grows with the
/// gesture. For a provisional new event (calendarId=-1) it uses accentGreen.
///
/// For existing events this renders the COMPLETE tile in selected style
/// (solid fill, dark text). This is THE live preview during drag/resize —
/// kalender sizes this overlay while the gesture is active, so the tile
/// grows/shrinks in real time. The normal tile underneath is transparent
/// when selected, so this is the only visible layer.
Widget kalenderDropTargetTile(CalendarEvent event) {
  final ke = event as KalenderCalendarEvent;
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  return switch (ke.source) {
    EventItem(event: final e) when e.calendarId == -1 =>
      _buildDropTargetContent(ke, const Color(0xFF8BC9A3), isShort),
    EventItem(event: final e) => _CalendarColorConsumer(
        calendarId: e.calendarId,
        builder: (color) => _buildSelectedEventContent(ke, color, isShort),
      ),
    TaskItem(task: final t) =>
      _buildSelectedTaskContent(ke, t, isShort),
  };
}

/// Renders the provisional-event tile during drag-to-create.
///
/// Shows a low-opacity bordered block that grows with the drag gesture.
/// Only used for new events (calendarId == -1); existing events use
/// [_buildSelectedEventContent] / [_buildSelectedTaskContent] instead.
Widget _buildDropTargetContent(KalenderCalendarEvent ke, Color color, bool isShort) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: isShort
        ? Text(
            ke.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BmoColors.textPrimary,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ke.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BmoColors.textPrimary,
                ),
              ),
              if (ke.startTime != null)
                Text(
                  ke.endTime != null
                      ? '${_formatTime(ke.startTime!)}–${_formatTime(ke.endTime!)}'
                      : _formatTime(ke.startTime!),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    color: BmoColors.textMuted,
                  ),
                ),
            ],
          ),
  );
}

/// Builds the selected-style tile for an existing calendar event.
///
/// Tinted background with glow shadow, 3px left accent bar, no border.
/// Title in textPrimary, time in white 0.75 for legibility.
Widget _buildSelectedEventContent(KalenderCalendarEvent ke, Color color, bool isShort) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 8,
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: isShort
                  ? Text(
                      ke.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ke.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BmoColors.textPrimary,
                          ),
                        ),
                        if (ke.startTime != null)
                          Text(
                            ke.endTime != null
                                ? '${_formatTime(ke.startTime!)}–${_formatTime(ke.endTime!)}'
                                : _formatTime(ke.startTime!),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds the selected-style tile for a task (mission).
///
/// Tinted background with glow shadow, 3px left accent bar, no border.
/// Title in textPrimary, time in white 0.75 for legibility.
Widget _buildSelectedTaskContent(KalenderCalendarEvent ke, Task t, bool isShort) {
  final color = _taskColor(ke);
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 8,
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: isShort
                  ? Text(
                      ke.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ke.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BmoColors.textPrimary,
                          ),
                        ),
                        if (ke.startTime != null)
                          Text(
                            _formatTime(ke.startTime!),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Renders the tile at the original position while an existing event is being
/// dragged. Drawn with reduced opacity so the user sees where the event was.
Widget kalenderTileWhenDragging(CalendarEvent event) {
  final ke = event as KalenderCalendarEvent;
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  return switch (ke.source) {
    EventItem(event: final e) when e.calendarId == -1 =>
      _buildDraggingContent(ke, const Color(0xFF8BC9A3), isShort),
    EventItem(event: final e) => _CalendarColorConsumer(
        calendarId: e.calendarId,
        builder: (calColor) => _buildDraggingContent(ke, calColor, isShort),
      ),
    TaskItem() => _buildDraggingContent(ke, _taskColor(ke), isShort),
  };
}

Widget _buildDraggingContent(KalenderCalendarEvent ke, Color color, bool isShort) {
  return Opacity(
    opacity: 0.5,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: isShort
          ? Text(
              ke.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: BmoColors.textPrimary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ke.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: BmoColors.textPrimary,
                  ),
                ),
                if (ke.startTime != null)
                  Text(
                    ke.endTime != null
                        ? '${_formatTime(ke.startTime!)}–${_formatTime(ke.endTime!)}'
                        : _formatTime(ke.startTime!),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      color: BmoColors.textMuted,
                    ),
                  ),
              ],
            ),
    ),
  );
}

/// Renders the tile that follows the pointer during drag of an existing event.
Widget kalenderFeedbackTile(CalendarEvent event, Size dropTargetWidgetSize) {
  final ke = event as KalenderCalendarEvent;
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  return Material(
    child: switch (ke.source) {
      EventItem(event: final e) when e.calendarId == -1 =>
        _buildFeedbackContent(ke, const Color(0xFF8BC9A3), isShort, dropTargetWidgetSize),
      EventItem(event: final e) => _CalendarColorConsumer(
          calendarId: e.calendarId,
          builder: (calColor) =>
              _buildFeedbackContent(ke, calColor, isShort, dropTargetWidgetSize),
        ),
      TaskItem() => _buildFeedbackContent(ke, _taskColor(ke), isShort, dropTargetWidgetSize),
    },
  );
}

Widget _buildFeedbackContent(
    KalenderCalendarEvent ke, Color color, bool isShort, Size size) {
  return Container(
    width: size.width,
    height: size.height,
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(4),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: isShort
        ? Text(
            ke.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: BmoColors.textPrimary,
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ke.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: BmoColors.textPrimary,
                ),
              ),
              if (ke.startTime != null)
                Text(
                  ke.endTime != null
                      ? '${_formatTime(ke.startTime!)}–${_formatTime(ke.endTime!)}'
                      : _formatTime(ke.startTime!),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    color: BmoColors.textMuted,
                  ),
                ),
            ],
          ),
  );
}

/// Minimal wrapper that watches [calendarsByIdProvider] for a specific
/// [calendarId] and calls [builder] with the resolved color.
class _CalendarColorConsumer extends ConsumerWidget {
  final int calendarId;
  final Widget Function(Color color) builder;

  const _CalendarColorConsumer({
    required this.calendarId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsById = ref.watch(calendarsByIdProvider);
    final calendar = calendarsById[calendarId];
    final color = _hexToColor(calendar?.color ?? '#8BC9A3');
    return builder(color);
  }
}
