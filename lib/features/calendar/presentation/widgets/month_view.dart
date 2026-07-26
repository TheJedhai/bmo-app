import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart' as app;
import 'kalender_events.dart';

class MonthView extends ConsumerStatefulWidget {
  final DateTime focusedMonth;
  final void Function(DateTime day) onDayTap;

  const MonthView({
    super.key,
    required this.focusedMonth,
    required this.onDayTap,
  });

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late final CalendarController _calendarController;
  late final DefaultEventsController _eventsController;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _eventsController = DefaultEventsController();
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthRange = (
      year: widget.focusedMonth.year,
      month: widget.focusedMonth.month,
    );
    final eventsAsync = ref.watch(eventsProvider(monthRange));

    return eventsAsync.when(
      loading: () => const _LoadingWidget(),
      error: (_, _) => const _ErrorWidget(),
      data: (events) {
        _syncEvents(events);
        return _buildCalendar();
      },
    );
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

    return CalendarView(
      eventsController: _eventsController,
      calendarController: _calendarController,
      viewConfiguration: MonthViewConfiguration.singleMonth(
        initialDateTime: widget.focusedMonth,
        firstDayOfWeek: DateTime.sunday,
        showWeekNumbers: false,
      ),
      callbacks: CalendarCallbacks(
        onTapped: (date) => widget.onDayTap(date),
        onEventTapped: (event, _) {
          final ke = event as KalenderCalendarEvent;
          widget.onDayTap(ke.source.occurrenceDate);
        },
      ),
      components: CalendarComponents(
        monthComponents: MonthComponents(
          bodyComponents: MonthBodyComponents(
            monthDayCellBuilder:
                MonthDayCell.shadeAdjacentMonths(color: BmoColors.screenBg.withValues(alpha: 0.4)),
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
    );
  }

  Widget _buildDayHeader(DateTime date, MonthDayHeaderStyle? style) {
    final isToday = _isToday(date);
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
            color: isToday ? BmoColors.screenBg : BmoColors.textPrimary,
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

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: BmoColors.accentGreen,
        strokeWidth: 2,
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Erro ao carregar eventos',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textMuted,
        ),
      ),
    );
  }
}
