import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_back_button.dart';
import '../../../features/missions/data/missions_providers.dart';
import '../../../features/missions/data/models/task.dart';
import '../../../features/missions/presentation/widgets/task_form_modal.dart';
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
    if (item is TaskItem) {
      _showTaskBottomSheet(item.task);
      return;
    }
    final event = (item as EventItem).event;
    final result = await showEventFormModal(context, event: event);
    if (result != null && mounted) {
      final month = ref.read(visibleMonthProvider);
      ref.read(eventsProvider(month).notifier).refresh();
    }
  }

  void _showTaskBottomSheet(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        onCompleted: () {
          Navigator.of(context).pop();
          final month = ref.read(visibleMonthProvider);
          ref.read(calendarTasksProvider(month).notifier).refresh();
        },
        onEdited: () {
          Navigator.of(context).pop();
          final month = ref.read(visibleMonthProvider);
          ref.read(calendarTasksProvider(month).notifier).refresh();
        },
      ),
    );
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

/// Bottom sheet for viewing a mission from the calendar.
///
/// Shows title, notes, due date/time, folder name, and recurrence info.
/// Actions: "Concluir" (complete) and "Editar" (opens [TaskFormModal]).
class _TaskDetailSheet extends ConsumerWidget {
  final Task task;
  final VoidCallback onCompleted;
  final VoidCallback onEdited;

  const _TaskDetailSheet({
    required this.task,
    required this.onCompleted,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider).valueOrNull ?? const [];
    final folder = folders.where((f) => f.id == task.folderId).firstOrNull;

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BmoColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                task.title,
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 13,
                  color: BmoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Due date
              if (task.dueDate != null) ...[
                _detailRow(
                  Icons.calendar_today_outlined,
                  _formatTaskDate(task.dueDate!, task.dueTime),
                ),
              ],

              // Folder
              if (folder != null)
                _detailRow(Icons.folder_outlined, folder.name),

              // Recurrence
              if (task.recurrenceType != null)
                _detailRow(Icons.repeat, _recurrenceLabel(task)),

              // Notes
              if (task.notes != null && task.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  task.notes!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _complete(context, ref),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Concluir'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BmoColors.accentGreen,
                        side: BorderSide(
                          color: BmoColors.accentGreen.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BmoColors.accentGreen,
                        foregroundColor: BmoColors.screenBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(missionsRepositoryProvider);
      await repo.completeTask(task.id);
      if (context.mounted) onCompleted();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao concluir: $e'),
            backgroundColor: BmoColors.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _edit(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => TaskFormModal(task: task),
    );
    if (context.mounted) onEdited();
  }

  static Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: BmoColors.textMuted),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTaskDate(DateTime date, String? dueTime) {
    const months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
      'jul', 'ago', 'set', 'out', 'nov', 'dez',
    ];
    final base = '${date.day} de ${months[date.month - 1]} ${date.year}';
    if (dueTime != null) {
      return '$base às $dueTime';
    }
    return base;
  }

  static String _recurrenceLabel(Task task) {
    return switch (task.recurrenceType!) {
      RecurrenceType.daily => 'Diário',
      RecurrenceType.weekly => 'Semanal',
      RecurrenceType.monthly => 'Mensal',
    };
  }
}

