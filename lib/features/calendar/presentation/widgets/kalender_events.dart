import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart' as app;

/// Wraps our [app.CalendarEvent] model so it can be rendered by kalender.
class KalenderCalendarEvent extends CalendarEvent {
  final app.CalendarEvent source;

  KalenderCalendarEvent({
    required super.dateTimeRange,
    required this.source,
    EventInteraction? interaction,
  }) : super(
          id: '${source.id}_${source.occurrenceDate.toIso8601String()}',
          // Recurring events are not draggable/resizable — we don't support
          // per-occurrence editing, so dragging one occurrence would move all.
          interaction: interaction ??
              (source.isRecurring
                  ? EventInteraction.allowNone()
                  : EventInteraction.allowAll()),
        );

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
      source: dummySource,
      interaction: EventInteraction.allowAll(),
    );
  }

  String get title => source.title ?? '(sem título)';
  bool get allDay => source.allDay;
  String? get startTime => source.startTime;
  String? get endTime => source.endTime;

  /// Returns a [KalenderCalendarEvent] copy with the given fields replaced.
  ///
  /// Preserves [source] and all custom fields. Carries the existing [id]
  /// over — required by kalender so selection/layout lookups keep working.
  @override
  KalenderCalendarEvent copyWith({
    DateTimeRange? dateTimeRange,
    EventInteraction? interaction,
  }) {
    debugPrint('[B] KalenderCalendarEvent.copyWith — start: ${dateTimeRange?.start}, end: ${dateTimeRange?.end}');
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
      other.source.title == source.title &&
      other.source.allDay == source.allDay &&
      other.source.startTime == source.startTime &&
      other.source.endTime == source.endTime;

  @override
  int get hashCode => Object.hash(
        super.hashCode,
        source.title,
        source.allDay,
        source.startTime,
        source.endTime,
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
/// Wrapped in [Consumer] so calendar color/name changes reflect immediately
/// without re-fetching events.
Widget kalenderMonthTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  final ke = event as KalenderCalendarEvent;
  return Consumer(
    builder: (context, ref, _) {
      final calendarsById = ref.watch(calendarsByIdProvider);
      final calendar = calendarsById[ke.source.calendarId];
      final color = _hexToColor(calendar?.color ?? '#8BC9A3');
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
    },
  );
}

/// Builds an event tile for multi-day views (week/day body).
///
/// Shows title and time; in short tiles, only title with ellipsis.
/// Wrapped in [Consumer] so calendar color changes reflect immediately.
Widget kalenderMultiDayTileBuilder(CalendarEvent event, DateTimeRange tileRange) {
  debugPrint('[B] kalenderMultiDayTileBuilder — id: ${event.id}, start: ${event.start}, end: ${event.end}');
  if (event is! KalenderCalendarEvent) {
    return Container(
      color: const Color(0xFF8BC9A3),
      child: const Text('novo', style: TextStyle(color: Color(0xFF1E1F23))),
    );
  }
  final ke = event;
  return Consumer(
    builder: (context, ref, _) {
      final calendarsById = ref.watch(calendarsByIdProvider);
      final calendar = calendarsById[ke.source.calendarId];
      final color = _hexToColor(calendar?.color ?? '#8BC9A3');
      final durationMinutes = ke.end.difference(ke.start).inMinutes;
      final isShort = durationMinutes <= 30;
      final isRecurring = ke.source.isRecurring;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
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
                  if (isRecurring)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        Icons.repeat,
                        size: 10,
                        color: BmoColors.textMuted.withValues(alpha: 0.5),
                      ),
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
                      if (isRecurring)
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.repeat,
                            size: 10,
                            color: BmoColors.textMuted.withValues(alpha: 0.5),
                          ),
                        ),
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
      );
    },
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
      final calendar = calendarsById[ke.source.calendarId];
      final color = _hexToColor(calendar?.color ?? '#8BC9A3');

      return ClipRect(
        child: Container(
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
        ),
      );
    },
  );
}

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
/// gesture. For a provisional new event (calendarId=-1) it uses accentGreen;
/// for existing events it uses the event's calendar color.
Widget kalenderDropTargetTile(CalendarEvent event) {
  final ke = event as KalenderCalendarEvent;
  // Provisional events have calendarId=-1 → use accentGreen.
  final color = ke.source.calendarId == -1
      ? const Color(0xFF8BC9A3)
      : _hexToColor('#8BC9A3'); // Will be overridden in Consumer below for real events.
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  // For provisional events (drag-to-create), render directly without Consumer
  // since there's no real calendar to look up.
  if (ke.source.calendarId == -1) {
    return _buildDropTargetContent(ke, color, isShort);
  }

  // For existing events, look up the calendar color.
  return _CalendarColorConsumer(
    calendarId: ke.source.calendarId,
    builder: (calColor) => _buildDropTargetContent(ke, calColor, isShort),
  );
}

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

/// Renders the tile at the original position while an existing event is being
/// dragged. Drawn with reduced opacity so the user sees where the event was.
Widget kalenderTileWhenDragging(CalendarEvent event) {
  final ke = event as KalenderCalendarEvent;
  final color = ke.source.calendarId == -1
      ? const Color(0xFF8BC9A3)
      : _hexToColor('#8BC9A3');
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  if (ke.source.calendarId == -1) {
    return _buildDraggingContent(ke, color, isShort);
  }

  return _CalendarColorConsumer(
    calendarId: ke.source.calendarId,
    builder: (calColor) => _buildDraggingContent(ke, calColor, isShort),
  );
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
  final color = ke.source.calendarId == -1
      ? const Color(0xFF8BC9A3)
      : _hexToColor('#8BC9A3');
  final durationMinutes = ke.end.difference(ke.start).inMinutes;
  final isShort = durationMinutes <= 30;

  if (ke.source.calendarId == -1) {
    return Material(
      child: _buildFeedbackContent(ke, color, isShort, dropTargetWidgetSize),
    );
  }

  return Material(
    child: _CalendarColorConsumer(
      calendarId: ke.source.calendarId,
      builder: (calColor) =>
          _buildFeedbackContent(ke, calColor, isShort, dropTargetWidgetSize),
    ),
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
