import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/bmo_theme.dart';

import '../../../dashboard/widgets/bmo_density.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar_event.dart';
import 'event_time_format.dart';

/// Dashboard card: próximos 5 eventos.
class CalendarDashCard extends ConsumerWidget {
  final Color accent;

  const CalendarDashCard({super.key, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = BmoDensity.of(context);
    final upcomingAsync = ref.watch(
      upcomingEventsProvider(density.isCompact ? 3 : 5),
    );

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

class _EventRow extends ConsumerWidget {
  final CalendarEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = BmoDensity.of(context);
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

    final time = event.startTime;
    final timeLabel = event.allDay || time == null ? '' : formatEventTime(time);

    final calendarsById = ref.watch(calendarsByIdProvider);
    final calendar = calendarsById[event.calendarId];
    final color = _hexToColor(calendar?.color ?? '#8BC9A3');

    // Data é o nível mais silencioso — um degrau abaixo do rótulo (hora).
    final dateFontSize = density.labelFontSize - 1;
    // A barra de cor acompanha a densidade pra não ficar desproporcional
    // com a fonte maior do regular.
    final barHeight = density.isCompact ? 28.0 : 34.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Color bar
          Container(
            width: 3,
            height: barHeight,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          // Date — IntrinsicWidth: "Amanhã"/"27 ago." cabem sem ellipsis
          // em qualquer densidade, sem largura mágica.
          IntrinsicWidth(
            child: Text(
              dateLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: dateFontSize,
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
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: density.labelFontSize,
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
                      fontSize: density.bodyFontSize,
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

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return const Color(0xFF8BC9A3);
}
