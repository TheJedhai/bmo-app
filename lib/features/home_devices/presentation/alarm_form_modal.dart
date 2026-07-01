import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../missions/data/models/task.dart';
import '../data/alarms_client.dart';
import '../data/device_alarm.dart';

import '../providers/alarms_providers.dart';
import '../providers/devices_providers.dart';

class AlarmFormModal extends ConsumerStatefulWidget {
  final DeviceAlarm? alarm;

  const AlarmFormModal({super.key, this.alarm});

  bool get isEditing => alarm != null;

  @override
  ConsumerState<AlarmFormModal> createState() => _AlarmFormModalState();
}

class _AlarmFormModalState extends ConsumerState<AlarmFormModal> {
  late final TextEditingController _nameCtrl;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  RecurrenceType? _recurrenceType;
  List<int> _recurrenceDays = <int>[];
  DeviceAlarmActionType _actionType = DeviceAlarmActionType.light;
  String? _deviceName;
  String? _targetState; // 'ON' or 'OFF'
  int? _sceneId;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    _nameCtrl = TextEditingController(text: alarm?.name ?? '');
    _dueDate = alarm?.dueDate;
    _dueTime = alarm?.dueTime != null
        ? _parseTimeOfDay(alarm!.dueTime!)
        : null;
    _recurrenceType = alarm?.recurrenceType;
    _recurrenceDays = alarm?.recurrenceDays != null
        ? List<int>.from(alarm!.recurrenceDays!)
        : <int>[];
    _actionType = alarm?.actionType ?? DeviceAlarmActionType.light;
    _deviceName = alarm?.deviceName;
    _targetState = alarm?.targetState ?? 'ON';
    _sceneId = alarm?.sceneId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool get _canSave {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_dueDate == null) return false;
    if (_dueTime == null) return false;
    if (_recurrenceType == RecurrenceType.weekly && _recurrenceDays.isEmpty) {
      return false;
    }
    if (_recurrenceType == RecurrenceType.monthly && _recurrenceDays.isEmpty) {
      return false;
    }
    if (_actionType == DeviceAlarmActionType.light && _deviceName == null) {
      return false;
    }
    if (_actionType == DeviceAlarmActionType.scene && _sceneId == null) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;

    setState(() => _saving = true);

    final notifier = ref.read(alarmsProvider.notifier);
    final name = _nameCtrl.text.trim();
    final dueDateStr =
        '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
    final dueTimeStr =
        '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';
    final recurrenceTypeStr = _recurrenceType?.name;

    try {
      if (widget.isEditing) {
        final alarm = widget.alarm!;
        await notifier.editAlarm(
          alarm.id,
          name: name,
          dueDate: dueDateStr,
          dueTime: dueTimeStr,
          recurrenceType: recurrenceTypeStr,
          recurrenceDays:
              (_recurrenceType == RecurrenceType.weekly ||
                      _recurrenceType == RecurrenceType.monthly)
                  ? _recurrenceDays
                  : null,
          clearRecurrence: _recurrenceType == null,
          actionType: _actionType.name,
          deviceName:
              _actionType == DeviceAlarmActionType.light ? _deviceName : null,
          clearDeviceName:
              _actionType != DeviceAlarmActionType.light,
          targetState:
              _actionType == DeviceAlarmActionType.light ? _targetState : null,
          clearTargetState:
              _actionType != DeviceAlarmActionType.light,
          sceneId: _actionType == DeviceAlarmActionType.scene ? _sceneId : null,
          clearSceneId: _actionType != DeviceAlarmActionType.scene,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarme atualizado')),
        );
      } else {
        await notifier.create(
          name: name,
          dueDate: dueDateStr,
          dueTime: dueTimeStr,
          recurrenceType: recurrenceTypeStr,
          recurrenceDays:
              (_recurrenceType == RecurrenceType.weekly ||
                      _recurrenceType == RecurrenceType.monthly)
                  ? _recurrenceDays
                  : null,
          actionType: _actionType.name,
          deviceName:
              _actionType == DeviceAlarmActionType.light ? _deviceName : null,
          targetState:
              _actionType == DeviceAlarmActionType.light ? _targetState : null,
          sceneId: _actionType == DeviceAlarmActionType.scene ? _sceneId : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarme criado')),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AlarmsApiException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
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

  void _removeDueDate() {
    setState(() {
      _dueDate = null;
      _dueTime = null;
      _recurrenceType = null;
      _recurrenceDays = <int>[];
    });
  }

  void _removeDueTime() {
    setState(() {
      _dueTime = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final scenesAsync = ref.watch(scenesProvider);
    final devicesAsync = ref.watch(devicesProvider);
    final hasScenes = scenesAsync.hasValue && scenesAsync.value!.isNotEmpty;

    // Auto-select first device if none selected
    if (_deviceName == null &&
        devicesAsync.hasValue &&
        devicesAsync.value!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _deviceName == null) {
          setState(() =>
              _deviceName = devicesAsync.value!.keys.first);
        }
      });
    }

    return Dialog(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    widget.isEditing ? 'Editar alarme' : 'Novo alarme',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 12,
                      color: BmoColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name
                    TextField(
                      controller: _nameCtrl,
                      autofocus: !widget.isEditing,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Nome do alarme',
                        hintStyle: TextStyle(color: BmoColors.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Due date
                    if (_dueDate == null)
                      _FormActionButton(
                        icon: Icons.calendar_today_outlined,
                        label: 'Definir data',
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
                          _FormClearButton(onTap: _removeDueDate),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Due time
                      if (_dueTime == null)
                        _FormActionButton(
                          icon: Icons.access_time,
                          label: 'Definir horário',
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
                            _FormClearButton(onTap: _removeDueTime),
                          ],
                        ),
                        const SizedBox(height: 10),
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

                    const SizedBox(height: 16),
                    const Divider(color: BmoColors.textMuted, height: 1),
                    const SizedBox(height: 16),

                    // Action section
                    _FormLabel(text: 'Ação', theme: theme),
                    const SizedBox(height: 6),

                    // Action type selector (only if scenes available)
                    if (hasScenes) ...[
                      Row(
                        children: [
                          _ActionTypeChip(
                            label: 'Dispositivo',
                            selected:
                                _actionType == DeviceAlarmActionType.light,
                            onTap: () => setState(() {
                              _actionType = DeviceAlarmActionType.light;
                              _sceneId = null;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _ActionTypeChip(
                            label: 'Cena',
                            selected:
                                _actionType == DeviceAlarmActionType.scene,
                            onTap: () => setState(() {
                              _actionType = DeviceAlarmActionType.scene;
                              _deviceName = null;
                              _targetState = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Device mode
                    if (_actionType == DeviceAlarmActionType.light) ...[
                      // Device dropdown
                      devicesAsync.when(
                        data: (devices) {
                          final names = devices.keys.toList();
                          return DropdownButtonFormField<String>(
                            key: ValueKey('device_$_deviceName'),
                            initialValue: names.contains(_deviceName)
                                ? _deviceName
                                : null,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              hintText: 'Selecionar dispositivo',
                            ),
                            dropdownColor: BmoColors.screenBgElevated,
                            style: theme.textTheme.bodySmall,
                            items: names.map((n) {
                              return DropdownMenuItem<String>(
                                value: n,
                                child: Text(
                                  n,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: BmoColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _deviceName = v);
                              }
                            },
                          );
                        },
                        loading: () => const SizedBox(
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 10),
                      // ON/OFF toggle
                      Row(
                        children: [
                          _ActionTypeChip(
                            label: 'Ligar (ON)',
                            selected: _targetState == 'ON',
                            onTap: () =>
                                setState(() => _targetState = 'ON'),
                          ),
                          const SizedBox(width: 8),
                          _ActionTypeChip(
                            label: 'Desligar (OFF)',
                            selected: _targetState == 'OFF',
                            onTap: () =>
                                setState(() => _targetState = 'OFF'),
                          ),
                        ],
                      ),
                    ],

                    // Scene mode
                    if (_actionType == DeviceAlarmActionType.scene)
                      scenesAsync.when(
                        data: (scenes) {
                          return DropdownButtonFormField<int>(
                            key: ValueKey('scene_$_sceneId'),
                            initialValue: scenes.any((s) => s.id == _sceneId)
                                ? _sceneId
                                : null,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              hintText: 'Selecionar cena',
                            ),
                            dropdownColor: BmoColors.screenBgElevated,
                            style: theme.textTheme.bodySmall,
                            items: scenes.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: BmoColors.textPrimary,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _sceneId = v);
                              }
                            },
                          );
                        },
                        loading: () => const SizedBox(
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

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
  }
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

class _FormLabel extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _FormLabel({required this.text, required this.theme});

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

class _FormActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _FormActionButton({
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

class _FormClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FormClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(Icons.close, size: 16, color: BmoColors.textMuted),
    );
  }
}

// ============================================================
// Action type chip
// ============================================================

class _ActionTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActionTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: selected ? BmoColors.screenBg : BmoColors.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: BmoColors.accentGreen,
      backgroundColor: BmoColors.screenBgElevated,
      side: BorderSide(
        color: selected ? BmoColors.accentGreen : BmoColors.textMuted,
      ),
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

// ============================================================
// Recurrence section (duplicated from task_form_modal —
// alarms are self-contained per the feature-folder convention)
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
              color:
                  selected ? BmoColors.accentGreen : BmoColors.screenBgElevated,
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
