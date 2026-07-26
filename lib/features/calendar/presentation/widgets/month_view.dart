import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
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
  }

  @override
  void dispose() {
    _calendarController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthRange = ref.watch(visibleMonthProvider);
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

    return Column(
      children: [
        _MonthNavigator(controller: _calendarController),
        Expanded(
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

class _MonthNavigator extends StatelessWidget {
  final CalendarController controller;

  const _MonthNavigator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange?>(
      valueListenable: controller.visibleDateTimeRange,
      builder: (context, range, _) {
        String label = '';
        if (range != null) {
          final mid = range.start.add(const Duration(days: 15));
          const months = [
            'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
            'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
          ];
          label = '${months[mid.month - 1]} ${mid.year}';
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
