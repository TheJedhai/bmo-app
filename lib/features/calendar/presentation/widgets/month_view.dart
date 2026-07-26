import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/calendar_visibility_provider.dart';
import '../../data/models/calendar_event.dart' as app;
import '../calendar_screen.dart';
import 'kalender_events.dart';

class MonthView extends ConsumerStatefulWidget {
  final AgendaViewMode viewMode;
  final void Function(DateTime day) onDayTap;
  final void Function(DateTime start, DateTime end) onCreateFromRange;

  const MonthView({
    super.key,
    required this.viewMode,
    required this.onDayTap,
    required this.onCreateFromRange,
  });

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late final CalendarController _calendarController;
  late final DefaultEventsController _eventsController;
  late ViewConfiguration _viewConfig;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _eventsController = DefaultEventsController();

    final initialMonth = ref.read(visibleMonthProvider);
    _viewConfig = _buildViewConfig(widget.viewMode, initialMonth);

    // Schedule initial event fetch after first frame so the listener in
    // build() is already set up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchEventsForMonth(initialMonth);
    });

    // Scroll to current time on initial open for day/week views.
    if (widget.viewMode == AgendaViewMode.day ||
        widget.viewMode == AgendaViewMode.week) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calendarController.animateToDateTime(
            DateTime.now(),
            pageDuration: Duration.zero,
            scrollDuration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewMode != oldWidget.viewMode) {
      final current = ref.read(visibleMonthProvider);
      _viewConfig = _buildViewConfig(widget.viewMode, current);
      // Scroll to current time when switching to day/week view.
      if (widget.viewMode == AgendaViewMode.day ||
          widget.viewMode == AgendaViewMode.week) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _calendarController.animateToDateTime(
              DateTime.now(),
              pageDuration: Duration.zero,
              scrollDuration: const Duration(milliseconds: 300),
            );
          }
        });
      }
    }
  }

  ViewConfiguration _buildViewConfig(AgendaViewMode mode, MonthRange initial) {
    final timeRange = TimeOfDayRange.allDay();
    const heightPerMinute = 0.9;

    switch (mode) {
      case AgendaViewMode.day:
        return MultiDayViewConfiguration.singleDay(
          name: 'Day',
          initialDateTime: DateTime.now(),
          firstDayOfWeek: DateTime.sunday,
          timeOfDayRange: timeRange,
          initialHeightPerMinute: heightPerMinute,
        );
      case AgendaViewMode.week:
        return MultiDayViewConfiguration.week(
          name: 'Week',
          initialDateTime: DateTime.now(),
          firstDayOfWeek: DateTime.sunday,
          timeOfDayRange: timeRange,
          initialHeightPerMinute: heightPerMinute,
        );
      case AgendaViewMode.month:
        return MonthViewConfiguration.singleMonth(
          initialDateTime: DateTime(initial.year, initial.month, 1),
          firstDayOfWeek: DateTime.sunday,
          showWeekNumbers: false,
        );
      case AgendaViewMode.agenda:
        // Agenda is handled separately; fallback to month config.
        return MonthViewConfiguration.singleMonth(
          initialDateTime: DateTime(initial.year, initial.month, 1),
          firstDayOfWeek: DateTime.sunday,
          showWeekNumbers: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for month changes — triggers event fetch without rebuilding
    // the CalendarView subtree. visibleMonthProvider is written by
    // _onPageChanged but never watched here.
    ref.listen(visibleMonthProvider, (prev, next) {
      if (prev != next) {
        _fetchEventsForMonth(next);
      }
    });

    // Listen for visibility toggles — re-filter current month events
    // without re-fetching, keeping CalendarView stable.
    ref.listen(calendarVisibilityProvider, (_, _) {
      _applyFilter();
    });

    return _buildCalendar();
  }

  /// Fetches events for [range], then applies visibility filter.
  /// Never triggers a widget rebuild.
  Future<void> _fetchEventsForMonth(MonthRange range) async {
    try {
      final notifier = ref.read(eventsProvider(range).notifier);
      await notifier.refresh();
      if (!mounted) return;
      _applyFilter();
    } catch (_) {
      // Fetch failed — keep previous events visible.
    }
  }

  /// Reads current month events, applies visibility filter, pushes to controller.
  /// Safe to call from either listener (month change or visibility toggle).
  void _applyFilter() {
    final monthRange = ref.read(visibleMonthProvider);
    final events =
        ref.read(eventsProvider(monthRange)).valueOrNull ?? const <app.CalendarEvent>[];
    final visibility = ref.read(calendarVisibilityProvider);
    final visible = filterVisibleEvents(events, visibility);
    _syncEvents(visible);
  }

  void _syncEvents(List<app.CalendarEvent> events) {
    _eventsController.replaceEvents(toKalenderEvents(events));
  }

  Widget _buildCalendar() {
    final tileComponents = TileComponents(
      tileBuilder: kalenderMonthTileBuilder,
    );

    final multiDayTileComponents = TileComponents(
      tileBuilder: kalenderMultiDayTileBuilder,
    );

    final overlayBuilders = OverlayBuilders(
      multiDayPortalOverlayButtonStringBuilder: (context, count) => '+$count mais',
    );

    return Column(
      children: [
        _MonthNavigator(
          controller: _calendarController,
          viewMode: widget.viewMode,
          initialMonth: ref.read(visibleMonthProvider),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 0),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  secondaryContainer: BmoColors.accentGreen,
                  onSecondaryContainer: BmoColors.screenBg,
                ),
              ),
              child: CalendarView(
              eventsController: _eventsController,
            calendarController: _calendarController,
            viewConfiguration: _viewConfig,
            callbacks: CalendarCallbacks(
              onPageChanged: _onPageChanged,
              onTapped: (date) => widget.onDayTap(date),
              onEventTapped: (event, _) {
                final ke = event as KalenderCalendarEvent;
                widget.onDayTap(ke.source.occurrenceDate);
              },
              onEventChanged: _onEventChanged,
              onEventCreate: _onEventCreate,
              onEventCreated: _onEventCreated,
            ),
            components: CalendarComponents(
              monthComponents: MonthComponents(
                bodyComponents: MonthBodyComponents(
                  monthDayCellBuilder: MonthDayCell.shadeAdjacentMonths(
                    color: BmoColors.screenBg.withValues(alpha: 0.4),
                  ),
                  monthDayHeaderBuilder: _buildDayHeader,
                  overlayBuilders: overlayBuilders,
                ),
                headerComponents: MonthHeaderComponents(
                  weekDayHeaderBuilder: _buildWeekDayHeader,
                ),
              ),
              monthComponentStyles: MonthComponentStyles(
                bodyStyles: MonthBodyComponentStyles(
                  monthDayHeaderStyle: const MonthDayHeaderStyle(
                    numberTextStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: BmoColors.textPrimary,
                    ),
                    margin: EdgeInsets.only(top: 2, bottom: 1),
                  ),
                ),
                headerStyles: MonthHeaderComponentStyles(
                  weekDayHeaderStyle: const WeekDayHeaderStyle(
                    padding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              multiDayComponents: MultiDayComponents(
                headerComponents: const MultiDayHeaderComponents(
                  dayHeaderStringBuilder: _buildShortDayName,
                  weekNumberBuilder: _buildAllDayLabel,
                ),
                bodyComponents: MultiDayBodyComponents(
                  timelineStringBuilder: _buildTimelineLabel,
                  hourLines: _buildHourLines,
                  timeIndicator: _buildTimeIndicator,
                ),
              ),
              multiDayComponentStyles: MultiDayComponentStyles(
                headerStyles: MultiDayHeaderComponentStyles(
                  dayHeaderStyle: DayHeaderStyle(
                    numberTextStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: BmoColors.textPrimary,
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: BmoColors.textMuted,
                    ),
                    mainAxisAlignment: MainAxisAlignment.start,
                  ),
                ),
                bodyStyles: MultiDayBodyComponentStyles(
                  timeIndicatorStyle: TimeIndicatorStyle(
                    lineColor: BmoColors.accentRed.withValues(alpha: 0.8),
                    thickness: 2,
                    circleColor: BmoColors.accentRed,
                    circleSize: const Size(12, 12),
                  ),
                  hourLinesStyle: HourLinesStyle(
                    color: BmoColors.textMuted.withValues(alpha: 0.15),
                    thickness: 1,
                  ),
                  timelineStyle: TimelineStyle(
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: BmoColors.textMuted,
                    ),
                  ),
                  daySeparatorStyle: DaySeparatorStyle(
                    color: BmoColors.textMuted.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
            ),
            header: CalendarHeader(
              multiDayTileComponents: TileComponents(
                tileBuilder: kalenderAllDayTileBuilder,
              ),
              multiDayHeaderConfiguration: const MultiDayHeaderConfiguration(
                showTiles: true,
                tileHeight: 22,
                eventPadding: EdgeInsets.only(left: 2, right: 2, bottom: 2),
              ),
            ),
            body: CalendarBody(
              monthTileComponents: tileComponents,
              monthBodyConfiguration: const MonthBodyConfiguration(
                tileHeight: 20,
                eventPadding: EdgeInsets.only(left: 1, right: 1, bottom: 1),
              ),
              multiDayTileComponents: multiDayTileComponents,
              multiDayBodyConfiguration: const MultiDayBodyConfiguration(
                showMultiDayEvents: false,
                minimumTileHeight: 18,
                horizontalPadding: EdgeInsets.only(left: 2, right: 4),
                eventLayoutStrategy: sideBySideLayoutStrategy,
                scrollPhysics: ClampingScrollPhysics(),
                pageScrollPhysics: NeverScrollableScrollPhysics(),
              ),
              interaction: CalendarInteraction(
                allowResizing: true,
                allowRescheduling: true,
                allowEventCreation: true,
              ),
              snapping: const CalendarSnapping(
                snapIntervalMinutes: 15,
              ),
            ),
            locale: 'pt_BR',
          ),
          ), // Theme
          ),
        ),
      ],
    );
  }

  /// Handles drag/resize completion: PATCH event with optimistic rollback.
  ///
  /// The kalender controller already shows the moved tile (optimistic UI).
  /// We persist via PATCH. On failure, re-apply filter from provider state
  /// to roll back the kalender controller to the last known-good position.
  void _onEventChanged(CalendarEvent event, CalendarEvent updatedEvent) {
    final ke = event as KalenderCalendarEvent;
    final source = ke.source;

    // Recurring events blocked from drag/resize (commit 3 guard).
    if (source.isRecurring) return;

    final newStart = updatedEvent.start;
    final newEnd = updatedEvent.end;

    // Snapshot kalender events for rollback: if the PATCH fails we need to
    // restore the tile positions. The provider hasn't been mutated yet, so
    // _applyFilter() will push the old state back.
    final monthRange = (
      year: source.occurrenceDate.year,
      month: source.occurrenceDate.month,
    );

    // Build API params.
    final newDate = '${newStart.year}-'
        '${newStart.month.toString().padLeft(2, '0')}-'
        '${newStart.day.toString().padLeft(2, '0')}';
    final newStartTime = '${newStart.hour.toString().padLeft(2, '0')}:'
        '${newStart.minute.toString().padLeft(2, '0')}';
    final newEndTime = '${newEnd.hour.toString().padLeft(2, '0')}:'
        '${newEnd.minute.toString().padLeft(2, '0')}';

    final repo = ref.read(calendarRepositoryProvider);
    final notifier = ref.read(eventsProvider(monthRange).notifier);

    repo.updateEvent(
      source.id,
      occurrenceDate: source.allDay ? newDate : null,
      startTime: source.allDay ? null : newStartTime,
      endTime: source.allDay ? null : newEndTime,
    ).then((_) {
      // Server accepted — refresh provider to sync.
      if (mounted) notifier.refresh();
    }).catchError((e) {
      // Rollback: re-filter from unchanged provider state.
      if (mounted) {
        _applyFilter();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao mover evento: $e'),
            backgroundColor: BmoColors.accentRed,
          ),
        );
      }
    });
  }

  /// Returns a provisional [KalenderCalendarEvent] so kalender can draw the
  /// tile while the user drags. The dummy event is NOT persisted — it lives
  /// only in the controller's newEvent/selectedEvent and is cleared when the
  /// drag ends or is cancelled.
  CalendarEvent? _onEventCreate(CalendarEvent event) {
    return KalenderCalendarEvent.provisional(
      dateTimeRange: event.dateTimeRange,
    );
  }

  /// Called when the drag-to-create gesture completes. Opens the creation
  /// modal with the final time range. If the user saves, the POST creates
  /// the real event; if cancelled, nothing remains.
  void _onEventCreated(CalendarEvent event) {
    widget.onCreateFromRange(event.start, event.end);
  }

  static String _buildShortDayName(BuildContext context, DateTime date) {
    const labels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    final idx = date.weekday % 7;
    return labels[idx];
  }

  static Widget _buildAllDayLabel(DateTimeRange range, dynamic style) {
    return const SizedBox.shrink();
  }

  static String _buildTimelineLabel(BuildContext context, TimeOfDay time) {
    if (time.minute != 0) return '';
    return time.format(context);
  }

  /// Draws hour lines at 60-minute intervals only (no half-hour lines).
  ///
  /// kalender's default [HourLines] uses a dynamic segment duration that drops
  /// to 30 minutes at certain zoom levels. Apple Calendar only shows full-hour
  /// lines, so we lock the segment duration at 60.
  static Widget _buildHourLines(
    double heightPerMinute,
    TimeOfDayRange timeOfDayRange,
    HourLinesStyle? style,
    TimelineStyle? timelineStyle,
  ) {
    const segmentDuration = 60;
    final segments = timeOfDayRange.splitIntoSegments(segmentDuration);

    final thickness = style?.thickness ?? 1;
    final color = style?.color;
    final indent = style?.indent ?? 0;
    final endIndent = style?.endIndent ?? 0;

    var previousXPosition = 0.0;
    final positionedLines = <Widget>[];
    for (final segment in segments) {
      final rangeHeight = heightPerMinute * segment.duration.inMinutes;
      final position = rangeHeight + previousXPosition;
      previousXPosition = position;

      positionedLines.add(
        Positioned(
          top: position,
          left: 0,
          right: 0,
          child: Container(
            margin: EdgeInsetsDirectional.only(start: indent, end: endIndent),
            height: thickness,
            color: color,
          ),
        ),
      );
    }

    return Stack(children: positionedLines);
  }

  /// Builds the time indicator (red now-line) with a time badge.
  static Widget _buildTimeIndicator(
    TimeOfDayRange timeOfDayRange,
    double heightPerMinute,
    TimeIndicatorStyle? style,
    Location? location,
  ) {
    return _BmoTimeIndicator(
      timeOfDayRange: timeOfDayRange,
      heightPerMinute: heightPerMinute,
      style: style,
    );
  }

  void _onPageChanged(DateTimeRange range) {
    // Pick a date inside the visible range regardless of view mode:
    // day view (1 day) → use start; week (7 days) → add 3; month (~30 days) → add 15.
    final daysInRange = range.duration.inDays;
    final mid = range.start.add(Duration(days: daysInRange ~/ 2));
    final newRange = (year: mid.year, month: mid.month);
    final current = ref.read(visibleMonthProvider);
    if (newRange != current) {
      ref.read(visibleMonthProvider.notifier).state = newRange;
    }
  }

  Widget _buildDayHeader(DateTime date, MonthDayHeaderStyle? style) {
    final isToday = _isToday(date);
    // Use the controller's own visible range — not visibleMonthProvider —
    // so dimming stays in sync with the actual rendered page, even during
    // transitions when the provider may have already advanced.
    final range = _calendarController.visibleDateTimeRange.value;
    final isInFocusedMonth = range != null &&
        date.year == range.start.add(const Duration(days: 15)).year &&
        date.month == range.start.add(const Duration(days: 15)).month;

    Color textColor;
    if (isToday) {
      textColor = BmoColors.screenBg;
    } else if (isInFocusedMonth) {
      textColor = BmoColors.textPrimary;
    } else {
      textColor = BmoColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 1),
      alignment: Alignment.center,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? BmoColors.accentGreen : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDayHeader(DateTime date, WeekDayHeaderStyle? style) {
    const labels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    final idx = date.weekday % 7;
    return Center(
      child: Text(
        labels[idx],
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: BmoColors.textSecondary,
        ),
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }
}

class _MonthNavigator extends StatelessWidget {
  final CalendarController controller;
  final AgendaViewMode viewMode;
  final MonthRange initialMonth;

  const _MonthNavigator({
    required this.controller,
    required this.viewMode,
    required this.initialMonth,
  });

  String _fallbackLabel(AgendaViewMode mode) {
    final now = DateTime.now();
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    const days = [
      'domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado',
    ];

    switch (mode) {
      case AgendaViewMode.day:
        final dayName = days[now.weekday % 7];
        return '$dayName, ${now.day} de ${months[now.month - 1]} ${now.year}';
      case AgendaViewMode.week:
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        final weekEnd = weekStart.add(const Duration(days: 6));
        String fmt(DateTime d) => '${d.day}/${d.month}';
        return '${fmt(weekStart)} – ${fmt(weekEnd)} ${weekStart.year}';
      case AgendaViewMode.month:
      case AgendaViewMode.agenda:
        return '${months[now.month - 1]} ${now.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange?>(
      valueListenable: controller.visibleDateTimeRange,
      builder: (context, range, _) {
        const months = [
          'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
          'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
        ];
        const days = [
          'domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado',
        ];

        final String label;
        if (viewMode == AgendaViewMode.day && range != null) {
          final d = range.start;
          final dayName = days[d.weekday % 7];
          label = '$dayName, ${d.day} de ${months[d.month - 1]} ${d.year}';
        } else if (viewMode == AgendaViewMode.week && range != null) {
          final start = range.start;
          final end = range.end.subtract(const Duration(days: 1));
          String fmt(DateTime d) => '${d.day}/${d.month}';
          label = '${fmt(start)} – ${fmt(end)} ${start.year}';
        } else if (range != null) {
          final mid = range.start.add(const Duration(days: 15));
          label = '${months[mid.month - 1]} ${mid.year}';
        } else {
          // Fallback when visibleDateTimeRange is still null on first render.
          label = _fallbackLabel(viewMode);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Today button
              _TodayButton(
                onPressed: () => controller.animateToDate(DateTime.now()),
              ),
              const SizedBox(width: 4),
              // Navigation arrows + label
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      color: BmoColors.textSecondary,
                      onPressed: () => controller.animateToPreviousPage(),
                      visualDensity: VisualDensity.compact,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: BmoColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      color: BmoColors.textSecondary,
                      onPressed: () => controller.animateToNextPage(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _TodayButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          backgroundColor: BmoColors.accentGreen.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: const Text(
          'Hoje',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BmoColors.accentGreen,
          ),
        ),
      ),
    );
  }
}

/// Time indicator (red now-line) with a time badge showing the current time
/// next to the red circle, Apple Calendar style.
class _BmoTimeIndicator extends StatefulWidget {
  final TimeOfDayRange timeOfDayRange;
  final double heightPerMinute;
  final TimeIndicatorStyle? style;

  const _BmoTimeIndicator({
    required this.timeOfDayRange,
    required this.heightPerMinute,
    this.style,
  });

  @override
  State<_BmoTimeIndicator> createState() => _BmoTimeIndicatorState();
}

class _BmoTimeIndicatorState extends State<_BmoTimeIndicator> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowTimeOfDay = TimeOfDay.fromDateTime(now);

    final startMinutes = widget.timeOfDayRange.start.hour * 60 + widget.timeOfDayRange.start.minute;
    final endMinutes = widget.timeOfDayRange.end.hour * 60 + widget.timeOfDayRange.end.minute;
    final nowMinutes = nowTimeOfDay.hour * 60 + nowTimeOfDay.minute;

    if (nowMinutes < startMinutes || nowMinutes >= endMinutes) {
      return const SizedBox.shrink();
    }

    final top = (nowMinutes - startMinutes) * widget.heightPerMinute;

    final lineColor = widget.style?.lineColor ?? Theme.of(context).colorScheme.error;
    final thickness = widget.style?.thickness ?? 1;
    final circleColor = widget.style?.circleColor ?? lineColor;
    final circleWidth = widget.style?.circleSize?.width ?? 10;
    final circleHeight = widget.style?.circleSize?.height ?? 10;

    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Offset so the circle center aligns with the left edge of the day column.
    const circleCenterOffset = 1.0;

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Horizontal line across full width.
          PositionedDirectional(
            top: top,
            start: 0,
            end: 0,
            child: Container(height: thickness, color: lineColor),
          ),
          // Circle + time badge at left edge.
          PositionedDirectional(
            top: top - circleHeight / 2,
            start: -(circleWidth / 2) + circleCenterOffset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleWidth,
                  height: circleHeight,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  timeString,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: circleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

