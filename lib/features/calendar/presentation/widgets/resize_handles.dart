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
    final location = context.location;
    if (!showStart(location: location) && !showEnd(location: location)) {
      return const SizedBox();
    }

    // Only vertical resizing matters — horizontal resize handles are disabled
    // in imprecise mode and we don't use them.
    final isVertical = axis == Axis.vertical;
    if (!isVertical) return const SizedBox();

    // Half of the touch target extends outside the tile so the visual sits
    // right at the edge.
    final touchWidth = BmoResizeHandlePositioner._kTouchWidth;
    final touchHeight = BmoResizeHandlePositioner._kTouchHeight;
    final halfTouchH = touchHeight / 2;
    final left = (size.width - touchWidth) / 2;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showStart(location: location))
          Positioned(
            top: -halfTouchH,
            left: left,
            width: touchWidth,
            height: touchHeight,
            child: ResizeHandle(
              event: event,
              tileComponents: tileComponents,
              direction: ResizeDirection.top,
              visual: _EventColoredHandle(event: event),
            ),
          ),
        if (showEnd(location: location))
          Positioned(
            bottom: -halfTouchH,
            left: left,
            width: touchWidth,
            height: touchHeight,
            child: ResizeHandle(
              event: event,
              tileComponents: tileComponents,
              direction: ResizeDirection.bottom,
              visual: _EventColoredHandle(event: event),
            ),
          ),
      ],
    );
  }
}

/// A resize handle visual that renders as a small rounded pill in the event's
/// calendar color.
///
/// The touch target (44x20) is larger than the visible indicator (20x3) so the
/// handle is easy to grab on touch screens.
class _EventColoredHandle extends ConsumerWidget {
  final CalendarEvent event;

  const _EventColoredHandle({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarsById = ref.watch(calendarsByIdProvider);
    final ke = event as KalenderCalendarEvent;
    final calendar = calendarsById[ke.source.calendarId];
    final color = _hexToColor(calendar?.color ?? '#8BC9A3');

    return Center(
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
  }

  static Color _hexToColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF8BC9A3);
  }
}
