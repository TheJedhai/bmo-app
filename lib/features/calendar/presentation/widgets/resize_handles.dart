import 'dart:math' as math;

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
    // Only vertical resizing — horizontal handles are not used.
    if (axis != Axis.vertical) return const SizedBox();

    // Wrap in Consumer so we react to selectedEventIdProvider and
    // calendarsByIdProvider changes immediately, without waiting for
    // a kalender-driven rebuild.
    return Consumer(
      builder: (context, ref, _) {
        final selectedId = ref.watch(selectedEventIdProvider);
        if (selectedId != event.id) return const SizedBox();

        // Calendar color for the pill.
        final calendarsById = ref.watch(calendarsByIdProvider);
        final ke = event as KalenderCalendarEvent;
        final calendar = calendarsById[ke.source.calendarId];
        final color = _hexToColor(calendar?.color ?? '#8BC9A3');

        // Touch-target dimensions — kept entirely inside the tile bounds.
        //
        // Clip.none lets us PAINT outside the tile but the parent's hit test
        // rejects pointer positions outside the tile's render box. Half of
        // the touch target was decorative and unreachable. By keeping the
        // target fully inside the tile (top: 0 / bottom: 0), the full area
        // is hittable.
        final touchWidth = BmoResizeHandlePositioner._kTouchWidth;
        // On short tiles (e.g. 30 min × 0.9 px/min ≈ 27 px), two 20 px
        // handles would overlap. Clamp each to at most half the tile height.
        final maxHandleHeight = (size.height / 2).floorToDouble();
        final touchHeight = math.min(
          BmoResizeHandlePositioner._kTouchHeight,
          maxHandleHeight,
        );
        final left = (size.width - touchWidth) / 2;

        final pill = Center(
          child: Container(
            width: BmoResizeHandlePositioner._kPillWidth,
            height: BmoResizeHandlePositioner._kPillHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(
                BmoResizeHandlePositioner._kPillRadius,
              ),
            ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (showStart())
              Positioned(
                top: 0,
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
                bottom: 0,
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
      },
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
