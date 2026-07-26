import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../data/calendar_providers.dart';
import 'kalender_events.dart';

/// Custom [ResizeHandlePositioner] that centers resize handles on the top and
/// bottom edges of the event tile, Apple Calendar style.
///
/// Unlike the default kalender positioner (which places handles at corners for
/// imprecise mode), this positions them centered on each edge for a cleaner
/// look. The visual is a small rounded pill in the event's calendar color, with
/// a touch target larger than the visible indicator.
///
/// Handles are only shown for the currently selected event (two-tap model).
/// Hover alone does not show handles — the user must tap an event first.
class BmoResizeHandlePositioner {
  /// The touch-target width for a resize handle (comfortable finger target).
  static const double _kTouchWidth = 44.0;

  /// The touch-target height for a resize handle.
  static const double _kTouchHeight = 20.0;

  /// The visible pill width.
  static const double _kPillWidth = 20.0;

  /// The visible pill height.
  static const double _kPillHeight = 3.0;

  /// The pill border radius.
  static const double _kPillRadius = 2.0;

  /// Returns a [ResizeHandles] instance for the given parameters.
  // ignore: long-parameter-list — signature required by kalender's ResizeHandlePositioner typedef
  static ResizeHandles call(
    CalendarEvent event,
    CalendarInteraction interaction,
    TileComponents tileComponents,
    DateTimeRange dateTimeRange,
    Size size,
    Axis axis,
    bool isImprecise,
  ) {
    return _BmoResizeHandles(
      event: event,
      interaction: interaction,
      tileComponents: tileComponents,
      dateTimeRange: dateTimeRange,
      size: size,
      axis: axis,
      isImprecise: isImprecise,
    );
  }
}

class _BmoResizeHandles extends ResizeHandles {
  const _BmoResizeHandles({
    required super.event,
    required super.interaction,
    required super.tileComponents,
    required super.dateTimeRange,
    required super.size,
    required super.axis,
    required super.isImprecise,
  });

  @override
  Widget build(BuildContext context) {
    // Only show handles when this event is selected via the two-tap model.
    // Kalender's hover still fires, but our handles paint nothing for
    // unselected events — equivalent to the fork's InputMode.imprecise guard.
    final container = ProviderScope.containerOf(context);
    final selectedId = container.read(selectedEventIdProvider);
    if (selectedId != event.id) return const SizedBox();

    if (!showStart() && !showEnd()) return const SizedBox();

    // Only vertical resizing — horizontal handles are disabled in imprecise
    // mode and we don't use them.
    if (axis != Axis.vertical) return const SizedBox();

    // Calendar color for the pill.
    final calendarsById = container.read(calendarsByIdProvider);
    final ke = event as KalenderCalendarEvent;
    final calendar = calendarsById[ke.source.calendarId];
    final color = _hexToColor(calendar?.color ?? '#8BC9A3');

    // Half of the touch target extends outside the tile so the visual sits
    // right at the edge.
    final touchWidth = BmoResizeHandlePositioner._kTouchWidth;
    final touchHeight = BmoResizeHandlePositioner._kTouchHeight;
    final halfTouchH = touchHeight / 2;
    final left = (size.width - touchWidth) / 2;

    final pill = Center(
      child: Container(
        width: BmoResizeHandlePositioner._kPillWidth,
        height: BmoResizeHandlePositioner._kPillHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius:
              BorderRadius.circular(BmoResizeHandlePositioner._kPillRadius),
        ),
      ),
    );

    // clipBehavior: Clip.none so the handle halves that extend beyond the tile
    // edge remain hittable.
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (showStart())
          Positioned(
            top: -halfTouchH,
            left: left,
            width: touchWidth,
            height: touchHeight,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  startResizeDetector,
                  IgnorePointer(child: pill),
                ],
              ),
            ),
          ),
        if (showEnd())
          Positioned(
            bottom: -halfTouchH,
            left: left,
            width: touchWidth,
            height: touchHeight,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  endResizeDetector,
                  IgnorePointer(child: pill),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return const Color(0xFF8BC9A3);
}
