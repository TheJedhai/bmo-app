import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../data/calendar_providers.dart';
import '../data/models/calendar_event.dart';
import 'widgets/agenda_view.dart';
import 'widgets/event_form_modal.dart';
import 'widgets/month_view.dart';

enum AgendaViewMode { month, agenda }

final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final viewModeProvider = StateProvider<AgendaViewMode>((ref) => AgendaViewMode.month);

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
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
          'Agenda',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        actions: [
          _ViewModeToggle(
            mode: viewMode,
            onChanged: (m) => ref.read(viewModeProvider.notifier).state = m,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: viewMode == AgendaViewMode.month
          ? MonthView(
              onDayTap: (day) {
                ref.read(selectedDayProvider.notifier).state = day;
                ref.read(viewModeProvider.notifier).state =
                    AgendaViewMode.agenda;
              },
            )
          : Column(
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
          _ToggleChip(
            label: 'Mês',
            icon: Icons.calendar_month,
            active: mode == AgendaViewMode.month,
            onTap: () => onChanged(AgendaViewMode.month),
          ),
          _ToggleChip(
            label: 'Agenda',
            icon: Icons.list_alt,
            active: mode == AgendaViewMode.agenda,
            onTap: () => onChanged(AgendaViewMode.agenda),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? BmoColors.accentGreen.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? BmoColors.accentGreen : BmoColors.textMuted,
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
