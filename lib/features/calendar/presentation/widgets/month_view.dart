import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/calendar_visibility_provider.dart';
import '../../data/models/calendar_event.dart' as app;
import 'kalender_events.dart';

class MonthView extends ConsumerStatefulWidget {
  final void Function(DateTime day) onDayTap;

  const MonthView({
    super.key,
    required this.onDayTap,
  });

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late final CalendarController _calendarController;
  late final DefaultEventsController _eventsController;
  late final MonthViewConfiguration _viewConfig;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _eventsController = DefaultEventsController();

    final initialMonth = ref.read(visibleMonthProvider);
    _viewConfig = MonthViewConfiguration.singleMonth(
      initialDateTime: DateTime(initialMonth.year, initialMonth.month, 1),
      firstDayOfWeek: DateTime.sunday,
      showWeekNumbers: false,
    );

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

    final overlayBuilders = OverlayBuilders(
      multiDayPortalOverlayButtonStringBuilder: (context, count) => '+$count mais',
    );

    return Column(
      children: [
        _MonthNavigator(
          controller: _calendarController,
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
            ),
            header: const CalendarHeader(),
            body: CalendarBody(
              monthTileComponents: tileComponents,
              monthBodyConfiguration: const MonthBodyConfiguration(
                tileHeight: 20,
                eventPadding: EdgeInsets.only(left: 1, right: 1, bottom: 1),
              ),
            ),
            locale: 'pt_BR',
          ),
          ),
        ),
      ],
    );
  }

  void _onPageChanged(DateTimeRange range) {
    // The 15th of the visible range always falls in the focused month,
    // even when the grid shows trailing/leading days from adjacent months.
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
  final MonthRange initialMonth;

  const _MonthNavigator({
    required this.controller,
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
        final String label;
        if (range != null) {
          final mid = range.start.add(const Duration(days: 15));
          label = '${months[mid.month - 1]} ${mid.year}';
        } else {
          // Fallback for initial render before onPageChanged fires.
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

