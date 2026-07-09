import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/missions_client.dart';
import '../../data/missions_providers.dart';
import '../../data/models/folder.dart';
import '../../data/models/task.dart';

class TaskFormModal extends ConsumerStatefulWidget {
  final Task? task;
  final int? initialFolderId;

  const TaskFormModal({super.key, this.task, this.initialFolderId});

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskFormModal> createState() => _TaskFormModalState();
}

class _TaskFormModalState extends ConsumerState<TaskFormModal> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late int _folderId;
  late int _priority;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  int? _reminderMinutesBefore;
  RecurrenceType? _recurrenceType;
  List<int> _recurrenceDays = <int>[];

  // Subtask management (only for editing existing non-recurring root tasks)
  Task? _editingTask;
  bool _showSubtaskInput = false;
  final _subtaskTitleCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleCtrl = TextEditingController(text: task?.title ?? '');
    _notesCtrl = TextEditingController(text: task?.notes ?? '');
    _folderId = task?.folderId ?? widget.initialFolderId ?? 0;
    _priority = task?.priority ?? 0;
    _dueDate = task?.dueDate;
    _dueTime = task?.dueTimeOfDay;
    _reminderMinutesBefore = task?.reminderMinutesBefore;
    _recurrenceType = task?.recurrenceType;
    _recurrenceDays = task?.recurrenceDays != null
        ? List<int>.from(task!.recurrenceDays!)
        : <int>[];
    _editingTask = task;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _subtaskTitleCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_titleCtrl.text.trim().isEmpty) return false;
    if (_recurrenceType == RecurrenceType.weekly && _recurrenceDays.isEmpty) {
      return false;
    }
    if (_recurrenceType == RecurrenceType.monthly && _recurrenceDays.isEmpty) {
      return false;
    }
    // Recurrence without dueDate is impossible via UI flow, defensive check
    if (_recurrenceType != null && _dueDate == null) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;

    setState(() => _saving = true);

    final repo = ref.read(missionsRepositoryProvider);
    final title = _titleCtrl.text.trim();
    final notes = _notesCtrl.text.trim().isEmpty
        ? null
        : _notesCtrl.text.trim();
    final dueTimeStr = _dueTime != null
        ? '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
        : null;

    try {
      if (widget.isEditing) {
        final task = widget.task!;

        final hadDueDate = task.dueDate != null;
        final hasDueDateNow = _dueDate != null;
        final hadDueTime = task.dueTime != null;
        final hasDueTimeNow = _dueTime != null;
        final hadRecurrence = task.recurrenceType != null;
        final hasRecurrenceNow = _recurrenceType != null;
        final hadReminder = task.reminderMinutesBefore != null;
        final hasReminderNow = _reminderMinutesBefore != null;

        await repo.updateTask(
          task.id,
          title: title,
          notes: notes,
          dueDate: hasDueDateNow ? _dueDate : null,
          clearDueDate: hadDueDate && !hasDueDateNow,
          dueTime: hasDueTimeNow ? dueTimeStr : null,
          clearDueTime: hadDueTime && !hasDueTimeNow,
          recurrenceType: hasRecurrenceNow ? _recurrenceType : null,
          clearRecurrence: hadRecurrence && !hasRecurrenceNow,
          recurrenceDays: (hasRecurrenceNow &&
                  (_recurrenceType == RecurrenceType.weekly ||
                      _recurrenceType == RecurrenceType.monthly))
              ? _recurrenceDays
              : null,
          folderId: _folderId,
          priority: _priority,
          reminderMinutesBefore: _reminderMinutesBefore,
          clearReminder: hadReminder && !hasReminderNow,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atualizada')),
        );
      } else {
        await repo.createTask(
          title: title,
          folderId: _folderId,
          notes: notes,
          dueDate: _dueDate,
          dueTime: dueTimeStr,
          recurrenceType: _recurrenceType,
          recurrenceDays: (_recurrenceType == RecurrenceType.weekly ||
                  _recurrenceType == RecurrenceType.monthly)
              ? _recurrenceDays
              : null,
          priority: _priority,
          reminderMinutesBefore: _reminderMinutesBefore,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Criada')),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on MissionsApiException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      final message = e.errorCode == 'reminder_requires_due_time'
          ? 'A notificação exige um horário'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _createSubtask() async {
    final title = _subtaskTitleCtrl.text.trim();
    if (title.isEmpty || _editingTask == null) return;

    final repo = ref.read(missionsRepositoryProvider);
    try {
      await repo.createTask(
        title: title,
        folderId: _editingTask!.folderId,
        parentId: _editingTask!.id,
      );
      // Re-fetch the parent task to get updated subtask list
      final updated = await repo.getTask(_editingTask!.id);
      setState(() {
        _editingTask = updated;
        _showSubtaskInput = false;
        _subtaskTitleCtrl.clear();
      });
    } on MissionsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _deleteSubtask(Task subtask) async {
    final repo = ref.read(missionsRepositoryProvider);
    try {
      await repo.deleteTask(subtask.id);
      if (_editingTask != null) {
        final updated = await repo.getTask(_editingTask!.id);
        if (mounted) setState(() => _editingTask = updated);
      }
    } on MissionsApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter'),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter'),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dueTime = picked);
    }
  }

  void _cyclePriority() {
    setState(() {
      _priority = (_priority + 1) % 3;
    });
  }

  void _removeDueDate() {
    setState(() {
      _dueDate = null;
      _dueTime = null;
      _reminderMinutesBefore = null;
      _recurrenceType = null;
      _recurrenceDays = <int>[];
    });
  }

  void _removeDueTime() {
    setState(() {
      _dueTime = null;
      _reminderMinutesBefore = null;
    });
  }

  void _toggleRecurrenceDay(int day) {
    setState(() {
      if (_recurrenceDays.contains(day)) {
        _recurrenceDays = _recurrenceDays.where((d) => d != day).toList();
      } else {
        _recurrenceDays = [..._recurrenceDays, day]..sort();
      }
    });
  }

  bool get _canHaveSubtasks =>
      widget.isEditing &&
      _editingTask != null &&
      _editingTask!.parentId == null &&
      _recurrenceType == null &&
      (_editingTask?.recurrenceType == null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final foldersAsync = ref.watch(foldersProvider);

    // Resolve effective folder ID: use task's folder, initialFolderId, or find default "Geral"
    final effectiveFolderId = _folderId;
    if (effectiveFolderId == 0 && foldersAsync.hasValue) {
      final defaultFolder = foldersAsync.value!.where((f) => f.isDefault).firstOrNull;
      if (defaultFolder != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _folderId == 0) {
            setState(() => _folderId = defaultFolder.id);
          }
        });
      }
    }

    final dialog = Dialog(
      backgroundColor: BmoColors.screenBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _Header(
              isEditing: widget.isEditing,
              priority: _priority,
              onPriorityTap: _cyclePriority,
              theme: theme,
            ),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    TextField(
                      controller: _titleCtrl,
                      autofocus: !widget.isEditing,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Título',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Notes
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      style: theme.textTheme.bodySmall,
                      decoration: const InputDecoration(
                        hintText: 'Notas',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Folder selector
                    _Label(text: 'Pasta', theme: theme),
                    const SizedBox(height: 6),
                    foldersAsync.when(
                      data: (folders) => _FolderSelector(
                        folders: folders,
                        selectedId: _folderId,
                        onChanged: (id) => setState(() => _folderId = id),
                        theme: theme,
                      ),
                      loading: () => const SizedBox(
                        height: 36,
                        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    // Due date
                    if (_dueDate == null)
                      _ActionButton(
                        icon: Icons.calendar_today_outlined,
                        label: 'Definir prazo',
                        onTap: _pickDate,
                        theme: theme,
                      )
                    else ...[
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: BmoColors.accentGreen),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateDisplay(_dueDate!),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: BmoColors.accentGreen,
                            ),
                          ),
                          const Spacer(),
                          _ClearButton(onTap: _removeDueDate),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Due time
                      if (_dueTime == null)
                        _ActionButton(
                          icon: Icons.access_time,
                          label: 'Adicionar horário',
                          onTap: _pickTime,
                          theme: theme,
                        )
                      else ...[
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 16, color: BmoColors.accentYellow),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimeDisplay(_dueTime!),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: BmoColors.accentYellow,
                              ),
                            ),
                            const Spacer(),
                            _ClearButton(onTap: _removeDueTime),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Reminder (only when due time is set)
                      if (_dueTime != null) ...[
                        const SizedBox(height: 10),
                        _ReminderDropdown(
                          value: _reminderMinutesBefore,
                          onChanged: (v) =>
                              setState(() => _reminderMinutesBefore = v),
                          theme: theme,
                        ),
                      ],

                      // Recurrence
                      const SizedBox(height: 4),
                      _RecurrenceSection(
                        recurrenceType: _recurrenceType,
                        recurrenceDays: _recurrenceDays,
                        onTypeChanged: (type) {
                          setState(() {
                            _recurrenceType = type;
                            _recurrenceDays = <int>[];
                          });
                        },
                        onDayToggled: _toggleRecurrenceDay,
                        theme: theme,
                      ),
                    ],

                    // Subtasks section (editing existing non-recurring root task)
                    if (_canHaveSubtasks) ...[
                      const SizedBox(height: 20),
                      const Divider(color: BmoColors.textMuted, height: 1),
                      const SizedBox(height: 12),
                      _Label(text: 'Subtarefas', theme: theme),
                      const SizedBox(height: 6),
                      if (_editingTask!.subtasks != null &&
                          _editingTask!.subtasks!.isNotEmpty)
                        ..._editingTask!.subtasks!.map((sub) => _SubtaskRow(
                              subtask: sub,
                              onDelete: () => _deleteSubtask(sub),
                              onEdit: () {
                                // Open edit modal for the subtask
                                Navigator.of(context).pop(true);
                                showDialog(
                                  context: context,
                                  builder: (_) =>
                                      TaskFormModal(task: sub),
                                );
                              },
                              theme: theme,
                            )),
                      if (_showSubtaskInput)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _subtaskTitleCtrl,
                                  autofocus: true,
                                  style: theme.textTheme.bodySmall,
                                  decoration: const InputDecoration(
                                    hintText: 'Título da subtarefa',
                                    hintStyle: TextStyle(
                                        color: BmoColors.textMuted),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _createSubtask(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _SmallIconButton(
                                icon: Icons.check,
                                color: BmoColors.accentGreen,
                                onTap: _createSubtask,
                              ),
                              _SmallIconButton(
                                icon: Icons.close,
                                color: BmoColors.textMuted,
                                onTap: () {
                                  setState(() {
                                    _showSubtaskInput = false;
                                    _subtaskTitleCtrl.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        _ActionButton(
                          icon: Icons.add,
                          label: 'Adicionar subtarefa',
                          onTap: () =>
                              setState(() => _showSubtaskInput = true),
                          theme: theme,
                        ),
                    ],
                    // Extra padding for scroll
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // Bottom buttons
            _BottomBar(
              onCancel: () => Navigator.of(context).pop(false),
              onSave: _canSave ? _save : null,
              saving: _saving,
              theme: theme,
            ),
          ],
        ),
      ),
    );

    return dialog;
  }
}

// ============================================================
// Header
// ============================================================

class _Header extends StatelessWidget {
  final bool isEditing;
  final int priority;
  final VoidCallback onPriorityTap;
  final ThemeData theme;

  const _Header({
    required this.isEditing,
    required this.priority,
    required this.onPriorityTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Text(
            isEditing ? 'Editar missão' : 'Nova missão',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 12,
              color: BmoColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onPriorityTap,
            child: Icon(
              priority == 0 ? Icons.outlined_flag : Icons.flag,
              color: _flagColor(priority),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Color _flagColor(int p) => switch (p) {
        1 => BmoColors.accentYellow,
        2 => Colors.redAccent,
        _ => BmoColors.textMuted,
      };
}

// ============================================================
// Bottom bar
// ============================================================

class _BottomBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final ThemeData theme;

  const _BottomBar({
    required this.onCancel,
    required this.onSave,
    required this.saving,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: saving ? null : onCancel,
            child: Text(
              'Cancelar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: BmoColors.textSecondary,
              ),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: BmoColors.screenBg,
              disabledBackgroundColor: BmoColors.textMuted,
            ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BmoColors.screenBg,
                    ),
                  )
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Shared small widgets
// ============================================================

class _Label extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _Label({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: BmoColors.textMuted,
        fontSize: 11,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: BmoColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.close, size: 16, color: BmoColors.textMuted),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ============================================================
// Folder selector
// ============================================================

class _FolderSelector extends StatelessWidget {
  final List<Folder> folders;
  final int selectedId;
  final ValueChanged<int> onChanged;
  final ThemeData theme;

  const _FolderSelector({
    required this.folders,
    required this.selectedId,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey('folder_$selectedId'),
      initialValue: folders.any((f) => f.id == selectedId) ? selectedId : null,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dropdownColor: BmoColors.screenBgElevated,
      style: theme.textTheme.bodySmall,
      items: folders.map((f) {
        return DropdownMenuItem<int>(
          value: f.id,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  f.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textPrimary,
                  ),
                ),
              ),
              if (f.isPersonal)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.person_outline,
                    size: 14,
                    color: BmoColors.textMuted,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ============================================================
// Recurrence section
// ============================================================

class _RecurrenceSection extends StatelessWidget {
  final RecurrenceType? recurrenceType;
  final List<int> recurrenceDays;
  final ValueChanged<RecurrenceType?> onTypeChanged;
  final ValueChanged<int> onDayToggled;
  final ThemeData theme;

  const _RecurrenceSection({
    required this.recurrenceType,
    required this.recurrenceDays,
    required this.onTypeChanged,
    required this.onDayToggled,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.repeat, size: 16, color: BmoColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<RecurrenceType?>(
                key: ValueKey('recurrence_$recurrenceType'),
                initialValue: recurrenceType,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: BmoColors.screenBgElevated,
                style: theme.textTheme.bodySmall,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Nunca')),
                  DropdownMenuItem(
                      value: RecurrenceType.daily, child: Text('Diária')),
                  DropdownMenuItem(
                      value: RecurrenceType.weekly, child: Text('Semanal')),
                  DropdownMenuItem(
                      value: RecurrenceType.monthly, child: Text('Mensal')),
                ],
                onChanged: onTypeChanged,
              ),
            ),
          ],
        ),
        if (recurrenceType == RecurrenceType.weekly) ...[
          const SizedBox(height: 8),
          _WeeklyDayChips(
            selectedDays: recurrenceDays,
            onToggled: onDayToggled,
            theme: theme,
          ),
        ],
        if (recurrenceType == RecurrenceType.monthly) ...[
          const SizedBox(height: 8),
          _MonthlyDayGrid(
            selectedDays: recurrenceDays,
            onToggled: onDayToggled,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _WeeklyDayChips extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<int> onToggled;
  final ThemeData theme;

  const _WeeklyDayChips({
    required this.selectedDays,
    required this.onToggled,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return Wrap(
      spacing: 4,
      children: List.generate(7, (i) {
        final day = i + 1; // ISO 8601: 1=Monday
        final selected = selectedDays.contains(day);
        return ChoiceChip(
          label: Text(
            labels[i],
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: selected ? BmoColors.screenBg : BmoColors.textSecondary,
            ),
          ),
          selected: selected,
          selectedColor: BmoColors.accentGreen,
          backgroundColor: BmoColors.screenBgElevated,
          side: BorderSide(
            color: selected ? BmoColors.accentGreen : BmoColors.textMuted,
          ),
          onSelected: (_) => onToggled(day),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        );
      }),
    );
  }
}

class _MonthlyDayGrid extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<int> onToggled;
  final ThemeData theme;

  const _MonthlyDayGrid({
    required this.selectedDays,
    required this.onToggled,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: List.generate(31, (i) {
        final day = i + 1;
        final selected = selectedDays.contains(day);
        return GestureDetector(
          onTap: () => onToggled(day),
          child: Container(
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? BmoColors.accentGreen : BmoColors.screenBgElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected ? BmoColors.accentGreen : BmoColors.textMuted,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: selected ? BmoColors.screenBg : BmoColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================
// Reminder dropdown
// ============================================================

class _ReminderDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final ThemeData theme;

  const _ReminderDropdown({
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.notifications_outlined,
            size: 16, color: BmoColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int?>(
            key: ValueKey('reminder_$value'),
            initialValue: value,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            dropdownColor: BmoColors.screenBgElevated,
            style: theme.textTheme.bodySmall,
            items: const [
              DropdownMenuItem(value: null, child: Text('Não notificar')),
              DropdownMenuItem(value: 0, child: Text('No horário')),
              DropdownMenuItem(value: 5, child: Text('5 min antes')),
              DropdownMenuItem(value: 15, child: Text('15 min antes')),
              DropdownMenuItem(value: 30, child: Text('30 min antes')),
              DropdownMenuItem(value: 60, child: Text('1 hora antes')),
              DropdownMenuItem(value: 1440, child: Text('1 dia antes')),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Subtask row (in the edit modal)
// ============================================================

class _SubtaskRow extends StatelessWidget {
  final Task subtask;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final ThemeData theme;

  const _SubtaskRow({
    required this.subtask,
    required this.onDelete,
    required this.onEdit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.subdirectory_arrow_right,
              size: 14, color: BmoColors.textMuted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 16, color: BmoColors.textMuted),
            color: BmoColors.screenBgElevated,
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: BmoColors.screenBgElevated,
                    title: const Text('Deletar subtarefa?',
                        style: TextStyle(color: BmoColors.textPrimary, fontSize: 14)),
                    content: Text(
                      "Deletar '${subtask.title}'?",
                      style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onDelete();
                        },
                        child: const Text('Deletar',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Deletar')),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Formatting helpers
// ============================================================

String _formatDateDisplay(DateTime date) {
  const weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  const months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

String _formatTimeDisplay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
