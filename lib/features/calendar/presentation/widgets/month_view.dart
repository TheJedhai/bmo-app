import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/calendar_visibility_provider.dart';
import '../../data/models/calendar_event.dart' as app;
import '../agenda_screen.dart';
import 'kalender_events.dart';

class MonthView extends ConsumerStatefulWidget {
  final AgendaViewMode viewMode;
  final void Function(DateTime day) onDayTap;

  const MonthView({
    super.key,
    required this.viewMode,
    required this.onDayTap,
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
    }
  }

  ViewConfiguration _buildViewConfig(AgendaViewMode mode, MonthRange initial) {
    final initialDate = DateTime(initial.year, initial.month, 1);
    final timeRange = TimeOfDayRange(
      start: TimeOfDay(hour: 6, minute: 0),
      end: TimeOfDay(hour: 23, minute: 0),
    );

    switch (mode) {
      case AgendaViewMode.day:
        return MultiDayViewConfiguration.singleDay(
          name: 'Day',
          initialDateTime: initialDate,
          firstDayOfWeek: DateTime.sunday,
          timeOfDayRange: timeRange,
          // ponytail: jump to roughly current hour on first open;
          // fine-grained scroll-to-now handled by animateToDateTime if needed.
          initialTimeOfDay: const TimeOfDay(hour: 8, minute: 0),
        );
      case AgendaViewMode.week:
        return MultiDayViewConfiguration.week(
          name: 'Week',
          initialDateTime: initialDate,
          firstDayOfWeek: DateTime.sunday,
          timeOfDayRange: timeRange,
          initialTimeOfDay: const TimeOfDay(hour: 8, minute: 0),
        );
      case AgendaViewMode.month:
        return MonthViewConfiguration.singleMonth(
          initialDateTime: initialDate,
          firstDayOfWeek: DateTime.sunday,
          showWeekNumbers: false,
        );
      case AgendaViewMode.agenda:
        // Agenda is handled separately; fallback to month config.
        return MonthViewConfiguration.singleMonth(
          initialDateTime: initialDate,
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
    ref.listen(calendarVisibilityProvider, (_, __) {
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
            padding: const EdgeInsets.only(right: 4),
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
              multiDayComponents: const MultiDayComponents(
                headerComponents: MultiDayHeaderComponents(
                  dayHeaderStringBuilder: _buildShortDayName,
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
                  ),
                ),
                bodyStyles: MultiDayBodyComponentStyles(
                  timeIndicatorStyle: TimeIndicatorStyle(
                    lineColor: BmoColors.accentRed.withValues(alpha: 0.8),
                    circleColor: BmoColors.accentRed,
                  ),
                  hourLinesStyle: HourLinesStyle(
                    color: BmoColors.textMuted.withValues(alpha: 0.08),
                  ),
                  timelineStyle: TimelineStyle(
                    textStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: BmoColors.textMuted,
                    ),
                  ),
                  daySeparatorStyle: DaySeparatorStyle(
                    color: BmoColors.textMuted.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            header: CalendarHeader(
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
              ),
            ),
            locale: 'pt_BR',
          ),
          ),
        ),
      ],
    );
  }

  static String _buildShortDayName(BuildContext context, DateTime date) {
    const labels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    final idx = date.weekday % 7;
    return labels[idx];
  }

  void _onPageChanged(DateTimeRange range) {
    final mid = range.start.add(const Duration(days: 15));
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
          label = '${months[initialMonth.month - 1]} ${initialMonth.year}';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                color: BmoColors.textSecondary,
                onPressed: () => controller.animateToPreviousPage(),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: BmoColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                color: BmoColors.textSecondary,
                onPressed: () => controller.animateToNextPage(),
              ),
            ],
          ),
        );
      },
    );
  }
}

