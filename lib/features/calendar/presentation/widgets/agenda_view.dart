import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart';

class AgendaView extends ConsumerWidget {
  final DateTime selectedDay;
  final void Function(CalendarEvent event) onEventTap;

  const AgendaView({
    super.key,
    required this.selectedDay,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthRange = (
      year: selectedDay.year,
      month: selectedDay.month,
    );
    final eventsAsync = ref.watch(eventsProvider(monthRange));

    return eventsAsync.when(
      loading: () => const _LoadingWidget(),
      error: (_, _) => const _AgendaErrorWidget(),
      data: (events) {
        final filtered = events
            .where((e) => e.occurrenceDate == _dateOnly(selectedDay))
            .toList()
          ..sort((a, b) {
            // All-day first, then by startTime.
            if (a.allDay && !b.allDay) return -1;
            if (!a.allDay && b.allDay) return 1;
            return (a.startTime ?? '').compareTo(b.startTime ?? '');
          });

        if (filtered.isEmpty) return const _EmptyDay();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final event = filtered[index];
            return _EventTile(
              event: event,
              onTap: () => onEventTap(event),
            );
          },
        );
      },
    );
  }

  DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

/// Full agenda listing: chronological from today, grouped by day.
class FullAgendaView extends ConsumerWidget {
  final void Function(CalendarEvent event) onEventTap;

  const FullAgendaView({super.key, required this.onEventTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingEventsProvider(90));

    return upcomingAsync.when(
      loading: () => const _LoadingWidget(),
      error: (_, _) => const _AgendaErrorWidget(),
      data: (events) {
        if (events.isEmpty) return const _EmptyAgenda();

        // Group by day.
        final grouped = <DateTime, List<CalendarEvent>>{};
        for (final e in events) {
          final day = DateTime(e.occurrenceDate.year,
              e.occurrenceDate.month, e.occurrenceDate.day);
          (grouped[day] ??= []).add(e);
        }

        final sortedDays = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];
            final dayEvents = grouped[day]!;
            return _DayGroup(
              date: day,
              events: dayEvents,
              onEventTap: onEventTap,
            );
          },
        );
      },
    );
  }
}

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final void Function(CalendarEvent event) onEventTap;

  const _DayGroup({
    required this.date,
    required this.events,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final dayName = DateFormat('EEEE', 'pt_BR').format(date);
    final dayMonth = DateFormat("d 'de' MMMM", 'pt_BR').format(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dayName,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isToday ? BmoColors.accentGreen : BmoColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dayMonth,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isToday
                      ? BmoColors.accentGreen.withValues(alpha: 0.8)
                      : BmoColors.textMuted,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: BmoColors.accentGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'hoje',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: BmoColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: BmoColors.screenBgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: BmoColors.textMuted.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < events.length; i++) ...[
                  _EventTile(
                    event: events[i],
                    onTap: () => onEventTap(events[i]),
                    showDivider: i < events.length - 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;
  final bool showDivider;

  const _EventTile({
    required this.event,
    required this.onTap,
    this.showDivider = false,
  });

  Color get _color {
    final hex = event.calendar?.color ?? '#8BC9A3';
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return const Color(0xFF8BC9A3);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Color indicator
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                // Time or all-day label
                SizedBox(
                  width: 48,
                  child: event.allDay
                      ? Text(
                          'dia todo',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: BmoColors.textMuted,
                          ),
                        )
                      : Text(
                          event.startTime ?? '',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: BmoColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.title != null && event.title!.isNotEmpty)
                        Text(
                          event.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: BmoColors.textPrimary,
                          ),
                        )
                      else
                        const Text(
                          '(sem título)',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: BmoColors.textMuted,
                          ),
                        ),
                      if (event.notes != null && event.notes!.isNotEmpty)
                        Text(
                          event.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: BmoColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Calendar name badge
                if (event.calendar != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      event.calendar!.name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _color,
                      ),
                    ),
                  ),
                // Recurrence icon
                if (event.isRecurring) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.repeat,
                    size: 14,
                    color: BmoColors.textMuted.withValues(alpha: 0.6),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: BmoColors.textMuted.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 74,
            color: BmoColors.textMuted.withValues(alpha: 0.1),
          ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nenhum evento neste dia',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Nenhum evento na agenda',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textMuted,
          ),
        ),
      ),
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

class _AgendaErrorWidget extends StatelessWidget {
  const _AgendaErrorWidget();

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
