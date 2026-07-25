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
  final Map<String, List<Color>> _dayMarkers = {};

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

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
    _dayMarkers.clear();
    for (final e in events) {
      final key = _dateKey(e.occurrenceDate);
      final color = _parseColor(e.calendar?.color ?? '#8BC9A3');
      (_dayMarkers[key] ??= []).add(color);
    }
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF8BC9A3);
  }

  Widget _buildCalendar() {
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
            monthDayCellBuilder: _buildDayCell,
            monthDayHeaderBuilder: _buildDayHeader,
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
                fontSize: 12,
                color: BmoColors.textPrimary,
              ),
              margin: EdgeInsets.only(top: 4, bottom: 2),
            ),
          ),
          headerStyles: MonthHeaderComponentStyles(
            weekDayHeaderStyle: const WeekDayHeaderStyle(
              padding: EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ),
      header: const CalendarHeader(),
      body: const CalendarBody(),
      locale: 'pt_BR',
    );
  }

  Widget _buildDayCell(MonthDayCellDetails details) {
    final markers = _dayMarkers[_dateKey(details.date)] ?? const <Color>[];
    final uniqueMarkers = markers.toSet().toList();

    return GestureDetector(
      onTap: () => widget.onDayTap(details.date),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: details.isToday
              ? BmoColors.accentGreen.withValues(alpha: 0.15)
              : null,
        ),
        child: Stack(
          children: [
            if (uniqueMarkers.isNotEmpty)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in uniqueMarkers.take(4))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (uniqueMarkers.length > 4)
                      Text(
                        '+${uniqueMarkers.length - 4}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          color: BmoColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, MonthDayHeaderStyle? style) {
    final isToday = _isToday(date);
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      child: Container(
        width: style?.buttonSize?.width ?? 28,
        height: style?.buttonSize?.height ?? 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isToday ? BmoColors.accentGreen : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
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
