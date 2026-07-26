import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/calendar_providers.dart';
import '../data/models/calendar_event.dart';
import 'widgets/agenda_view.dart';
import 'widgets/event_form_modal.dart';
import 'widgets/month_view.dart';

enum AgendaViewMode { day, week, month, agenda }

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final viewModeProvider = StateProvider<AgendaViewMode>((ref) => AgendaViewMode.week);

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(viewModeProvider);
    final selectedDay = ref.watch(selectedDayProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BmoBackButton(),
        title: Text(
          'Calendário',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          _ViewModeToggle(
            mode: viewMode,
            onChanged: (m) => ref.read(viewModeProvider.notifier).state = m,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.tune, size: 18),
            color: BmoColors.textMuted,
            tooltip: 'Gerenciar calendários',
            onPressed: () => context.push('/calendarios'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: viewMode == AgendaViewMode.agenda
          ? Column(
              children: [
                _AgendaHeader(
                  selectedDay: selectedDay,
                  onBackToMonth: () => ref
                      .read(viewModeProvider.notifier)
                      .state = AgendaViewMode.month,
                ),
                Expanded(
                  child: AgendaView(
                    selectedDay: selectedDay,
                    onEventTap: (event) => _openEditModal(event),
                  ),
                ),
              ],
            )
          : MonthView(
              viewMode: viewMode,
              onDayTap: (day) {
                ref.read(selectedDayProvider.notifier).state = day;
                ref.read(viewModeProvider.notifier).state =
                    AgendaViewMode.agenda;
              },
              onCreateFromRange: (start, end) =>
                  _openCreateModalForRange(start, end),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateModal,
        backgroundColor: BmoColors.accentGreen,
        foregroundColor: BmoColors.screenBg,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openCreateModal() async {
    final result = await showEventFormModal(
      context,
      initialDate: ref.read(selectedDayProvider),
    );
    if (result != null && mounted) {
      final month = ref.read(visibleMonthProvider);
      ref.read(eventsProvider(month).notifier).refresh();
    }
  }

  void _openCreateModalForRange(DateTime start, DateTime end) async {
    final startTime =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    final endTime =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    final result = await showEventFormModal(
      context,
      initialDate: start,
      initialStartTime: startTime,
      initialEndTime: endTime,
    );
    if (result != null && mounted) {
      final month = ref.read(visibleMonthProvider);
      ref.read(eventsProvider(month).notifier).refresh();
    }
  }

  void _openEditModal(CalendarEvent event) async {
    final result = await showEventFormModal(context, event: event);
    if (result != null && mounted) {
      final month = ref.read(visibleMonthProvider);
      ref.read(eventsProvider(month).notifier).refresh();
    }
  }
}

class _ViewModeToggle extends StatelessWidget {
  final AgendaViewMode mode;
  final ValueChanged<AgendaViewMode> onChanged;

  const _ViewModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TextChip(
            label: 'Dia',
            active: mode == AgendaViewMode.day,
            onTap: () => onChanged(AgendaViewMode.day),
          ),
          _TextChip(
            label: 'Semana',
            active: mode == AgendaViewMode.week,
            onTap: () => onChanged(AgendaViewMode.week),
          ),
          _TextChip(
            label: 'Mês',
            active: mode == AgendaViewMode.month,
            onTap: () => onChanged(AgendaViewMode.month),
          ),
          _TextChip(
            label: 'Agenda',
            active: mode == AgendaViewMode.agenda,
            onTap: () => onChanged(AgendaViewMode.agenda),
          ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TextChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? BmoColors.accentGreen.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? BmoColors.accentGreen : BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _AgendaHeader extends StatelessWidget {
  final DateTime selectedDay;
  final VoidCallback onBackToMonth;

  const _AgendaHeader({
    required this.selectedDay,
    required this.onBackToMonth,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;

    final dayName = _dayName(selectedDay.weekday);
    final formatted =
        '${selectedDay.day} de ${_monthName(selectedDay.month)} ${selectedDay.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            onPressed: onBackToMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Text(
            '$dayName, $formatted',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  isToday ? BmoColors.accentGreen : BmoColors.textSecondary,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
    );
  }

  String _dayName(int weekday) {
    const names = [
      'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom',
    ];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return names[month - 1];
  }
}
