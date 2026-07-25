import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/bmo_theme.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart';

/// Dashboard card: próximos 5 eventos.
class CalendarDashCard extends ConsumerWidget {
  final Color accent;

  const CalendarDashCard({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingEventsProvider(5));

    return upcomingAsync.when(
      loading: () => const _LoadingContent(),
      error: (_, _) => const _EmptyContent(),
      data: (events) {
        if (events.isEmpty) return const _EmptyContent();
        return _buildContent(events);
      },
    );
  }

  Widget _buildContent(List<CalendarEvent> events) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++) ...[
            _EventRow(event: events[i]),
            if (i < events.length - 1)
              Divider(
                height: 8,
                color: BmoColors.textMuted.withValues(alpha: 0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;

  const _EventRow({required this.event});

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
    final now = DateTime.now();
    final isToday = event.occurrenceDate.year == now.year &&
        event.occurrenceDate.month == now.month &&
        event.occurrenceDate.day == now.day;

    final isTomorrow = _isTomorrow(event.occurrenceDate);

    String dateLabel;
    if (isToday) {
      dateLabel = 'Hoje';
    } else if (isTomorrow) {
      dateLabel = 'Amanhã';
    } else {
      dateLabel = DateFormat("d MMM", 'pt_BR').format(event.occurrenceDate);
    }

    final timeLabel = event.allDay
        ? ''
        : (event.startTime ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Color bar
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          // Date
          SizedBox(
            width: 48,
            child: Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isToday ? BmoColors.accentGreen : BmoColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Title + time
          Expanded(
            child: Row(
              children: [
                if (timeLabel.isNotEmpty) ...[
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: BmoColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    event.title ?? '(sem título)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: event.title != null
                          ? BmoColors.textPrimary
                          : BmoColors.textMuted,
                      fontStyle:
                          event.title != null ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: BmoColors.accentYellow,
        ),
      ),
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Nenhum evento próximo',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}
