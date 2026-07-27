import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/calendar_providers.dart';
import 'widgets/calendar_item.dart';
import 'widgets/event_form_modal.dart';
import 'widgets/month_view.dart';

enum AgendaViewMode { day, week, month }

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
      body: MonthView(
              viewMode: viewMode,
              onDayTap: (day) {
                ref.read(selectedDayProvider.notifier).state = day;
                ref.read(viewModeProvider.notifier).state =
                    AgendaViewMode.day;
              },
              onEventEdit: (item) => _openEditModal(item),
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

  void _openEditModal(CalendarItem item) async {
    // Task detail bottom sheet handled in a later commit.
    if (item is TaskItem) return;
    final event = (item as EventItem).event;
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

