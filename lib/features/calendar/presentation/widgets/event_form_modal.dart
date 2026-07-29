import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../../../core/utils/provider_utils.dart';
import '../../data/calendar_client.dart';
import '../../data/calendar_providers.dart';
import '../../data/models/calendar.dart';
import '../../data/models/calendar_event.dart';
import 'scope_dialog.dart';

/// Presets de lembrete em minutos com rótulos pt-BR.
const _reminderPresets = [
  (0, 'Na hora'),
  (5, '5 min antes'),
  (15, '15 min antes'),
  (30, '30 min antes'),
  (60, '1 h antes'),
  (1440, '1 dia antes'),
  (2880, '2 dias antes'),
  (10080, '1 semana antes'),
];

/// Show a modal to create or edit a calendar event.
///
/// [event] null = create mode; non-null = edit mode (targets master `id`).
/// [initialStartTime]/[initialEndTime] pre-fill time fields (HH:MM) in create
/// mode, used when creating from a drag gesture in week/day views.
/// Returns the created/updated [CalendarEvent], or null if dismissed.
Future<CalendarEvent?> showEventFormModal(
  BuildContext context, {
  CalendarEvent? event,
  DateTime? initialDate,
  String? initialStartTime,
  String? initialEndTime,
}) {
  return showModalBottomSheet<CalendarEvent>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventFormSheet(
      event: event,
      initialDate: initialDate,
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
    ),
  );
}

class _EventFormSheet extends ConsumerStatefulWidget {
  final CalendarEvent? event;
  final DateTime? initialDate;
  final String? initialStartTime;
  final String? initialEndTime;

  const _EventFormSheet({
    this.event,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  ConsumerState<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<_EventFormSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Editable fields
  Calendar? _selectedCalendar;
  bool _allDay = false;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  RecurrenceType _recurrence = RecurrenceType.none;
  int _recurrenceInterval = 1;
  final Set<int> _recurrenceDays = {}; // Weekdays for weekly
  bool _lastDayOfMonth = false; // -1 in recurrence_days for monthly
  DateTime? _recurrenceEnd;
  int? _reminderMinutes;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _titleCtrl.text = e.title ?? '';
      _notesCtrl.text = e.notes ?? '';
      _allDay = e.allDay;
      _startDate = e.occurrenceDate;
      _endDate = e.endDate ?? e.occurrenceDate;
      if (e.startTime != null) {
        final parts = e.startTime!.split(':');
        _startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      if (e.endTime != null) {
        final parts = e.endTime!.split(':');
        _endTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      _recurrence = e.recurrenceType;
      _recurrenceInterval = e.recurrenceInterval;
      _recurrenceDays
        ..clear()
        ..addAll(e.recurrenceDays.where((d) => d > 0));
      _lastDayOfMonth = e.recurrenceDays.contains(-1);
      _recurrenceEnd = e.recurrenceEnd;
      _reminderMinutes = e.reminderMinutesBefore;
    } else {
      _startDate = widget.initialDate ?? DateTime.now();
      _endDate = _startDate;
      // Pre-fill times from drag gesture (week/day view create-by-drag).
      if (widget.initialStartTime != null) {
        final parts = widget.initialStartTime!.split(':');
        _startTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
      if (widget.initialEndTime != null) {
        final parts = widget.initialEndTime!.split(':');
        _endTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarsAsync = ref.watch(calendarsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: calendarsAsync.when(
            loading: () => const _FormLoading(),
            error: (_, _) => const _FormError(),
            data: (calendars) {
              // Set default calendar on first load.
              _selectedCalendar ??= (_isEditing
                  ? (calendars
                          .where((c) => c.id == widget.event?.calendarId)
                          .firstOrNull ??
                      calendars.where((c) => c.isDefault).firstOrNull ??
                      calendars.firstOrNull)
                  : calendars.where((c) => c.isDefault).firstOrNull ??
                      calendars.firstOrNull);
              return _buildForm(scrollController, calendars);
            },
          ),
        );
      },
    );
  }

  Widget _buildForm(
    ScrollController scrollCtrl,
    List<Calendar> calendars,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollCtrl,
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
            _isEditing ? 'Editar evento' : 'Novo evento',
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 14,
              color: BmoColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Title field
          _buildTextField(
            controller: _titleCtrl,
            label: 'Título',
            hint: 'ex.: Reunião de equipe',
          ),
          const SizedBox(height: 12),

          // Calendar selector
          _buildDropdown<Calendar?>(
            label: 'Calendário',
            value: _selectedCalendar,
            items: calendars.cast<Calendar?>(),
            itemLabel: (c) => c?.name ?? '',
            onChanged: (c) => setState(() => _selectedCalendar = c),
          ),
          const SizedBox(height: 12),

          // All-day toggle
          SwitchListTile(
            title: const Text(
              'Dia todo',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
            value: _allDay,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _allDay = v),
          ),

          // All-day reminder note
          if (_allDay && _reminderMinutes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'O lembrete será disparado às 09:00 do dia do evento.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: BmoColors.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Dates
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: 'Início',
                  date: _startDate,
                  onDateChanged: (d) => setState(() => _startDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: 'Fim',
                  date: _endDate,
                  onDateChanged: (d) => setState(() => _endDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Times (only when not all-day)
          if (!_allDay) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    label: 'Hora início',
                    time: _startTime,
                    onTimeChanged: (t) => setState(() => _startTime = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeField(
                    label: 'Hora fim',
                    time: _endTime,
                    onTimeChanged: (t) => setState(() => _endTime = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Recurrence
          _buildSectionLabel('Recorrência'),
          const SizedBox(height: 8),
          _buildDropdown<RecurrenceType>(
            label: 'Repetir',
            value: _recurrence,
            items: RecurrenceType.values,
            itemLabel: (r) => _recurrenceLabel(r),
            onChanged: (r) => setState(() => _recurrence = r ?? RecurrenceType.none),
          ),

          // Recurrence options
          if (_recurrence != RecurrenceType.none) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Intervalo:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: BmoColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: TextEditingController(
                      text: _recurrenceInterval.toString(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: BmoColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) {
                        _recurrenceInterval = n;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _recurrenceIntervalLabel(_recurrence),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: BmoColors.textMuted,
                  ),
                ),
              ],
            ),

            // Weekly: day picker
            if (_recurrence == RecurrenceType.weekly) ...[
              const SizedBox(height: 10),
              _buildWeekdayChips(),
            ],

            // Monthly: last day of month
            if (_recurrence == RecurrenceType.monthly) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text(
                  'Último dia do mês',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: BmoColors.textPrimary,
                  ),
                ),
                value: _lastDayOfMonth,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                onChanged: (v) => setState(() => _lastDayOfMonth = v ?? false),
              ),
            ],

            // Recurrence end
            const SizedBox(height: 8),
            _buildDateField(
              label: 'Data limite (opcional)',
              date: _recurrenceEnd,
              optional: true,
              onDateChanged: (d) => setState(() => _recurrenceEnd = d),
            ),
          ],

          const SizedBox(height: 16),

          // Reminder
          _buildSectionLabel('Lembrete'),
          const SizedBox(height: 8),
          _buildDropdown<int?>(
            label: 'Aviso',
            value: _reminderMinutes,
            items: [null, ..._reminderPresets.map((p) => p.$1)],
            itemLabel: (m) =>
                m == null
                    ? 'Sem lembrete'
                    : _reminderLabel(m),
            onChanged: (m) => setState(() => _reminderMinutes = m),
          ),

          const SizedBox(height: 16),

          // Notes
          _buildTextField(
            controller: _notesCtrl,
            label: 'Notas',
            hint: 'Detalhes do evento...',
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: BmoColors.accentGreen,
                foregroundColor: BmoColors.screenBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(_isEditing ? 'Salvar alterações' : 'Criar evento'),
            ),
          ),
          const SizedBox(height: 8),

          // Delete button (edit only)
          if (_isEditing)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(
                  foregroundColor: BmoColors.accentRed,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Excluir evento'),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- Form fields ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textMuted.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: BmoColors.screenBgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BmoColors.screenBgElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
              dropdownColor: BmoColors.screenBgElevated,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(itemLabel(item)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    bool optional = false,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: BmoColors.textSecondary,
              ),
            ),
            if (optional)
              const Text(
                ' (opcional)',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: BmoColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: BmoColors.accentGreen,
                        surface: BmoColors.screenBgElevated,
                        onSurface: BmoColors.textPrimary,
                      ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onDateChanged(picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BmoColors.screenBgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              date != null ? _formatDate(date) : 'Não definido',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: date != null
                    ? BmoColors.textPrimary
                    : BmoColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: BmoColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: BmoColors.accentGreen,
                        surface: BmoColors.screenBgElevated,
                        onSurface: BmoColors.textPrimary,
                      ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onTimeChanged(picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: BmoColors.screenBgElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayChips() {
    const labels = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final d = i + 1; // 1=Sun, 7=Sat
        final active = _recurrenceDays.contains(d);
        return FilterChip(
          label: Text(labels[i]),
          selected: active,
          onSelected: (sel) {
            setState(() {
              if (sel) {
                _recurrenceDays.add(d);
              } else {
                _recurrenceDays.remove(d);
              }
            });
          },
          selectedColor: BmoColors.accentGreen.withValues(alpha: 0.3),
          checkmarkColor: BmoColors.accentGreen,
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: active ? BmoColors.accentGreen : BmoColors.textSecondary,
          ),
          backgroundColor: BmoColors.screenBgElevated,
          side: BorderSide.none,
        );
      }),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: BmoColors.textPrimary,
      ),
    );
  }

  // --- Labels ---

  String _recurrenceLabel(RecurrenceType r) {
    return switch (r) {
      RecurrenceType.none => 'Não repetir',
      RecurrenceType.daily => 'Diário',
      RecurrenceType.weekly => 'Semanal',
      RecurrenceType.monthly => 'Mensal',
      RecurrenceType.yearly => 'Anual',
    };
  }

  String _recurrenceIntervalLabel(RecurrenceType r) {
    return switch (r) {
      RecurrenceType.daily => 'dia(s)',
      RecurrenceType.weekly => 'semana(s)',
      RecurrenceType.monthly => 'mês(es)',
      RecurrenceType.yearly => 'ano(s)',
      RecurrenceType.none => '',
    };
  }

  String _reminderLabel(int minutes) {
    for (final (m, label) in _reminderPresets) {
      if (m == minutes) return label;
    }
    return '$minutes min antes';
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // --- Actions ---

  String _formatDateISO(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeStr(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _save() async {
    if (_selectedCalendar == null) return;

    final title = _titleCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    final recurrenceDays = <int>[];
    if (_lastDayOfMonth) {
      recurrenceDays.add(-1);
    }
    recurrenceDays.addAll(_recurrenceDays.toList()..sort());

    final repo = ref.read(calendarRepositoryProvider);

    // For recurring event edits, ask scope first.
    String? scope;
    String? scopeOccurrenceDate;
    if (_isEditing && widget.event!.isRecurring) {
      final chosen = await showScopeDialog(context, action: 'editar');
      if (chosen == null || !mounted) return; // cancelled
      scope = chosen == RecurrenceScope.this_ ? 'this' : 'all';
      if (chosen == RecurrenceScope.this_) {
        scopeOccurrenceDate = _formatDateISO(widget.event!.occurrenceDate);
      }
    }

    try {
      if (_isEditing) {
        final updated = await repo.updateEvent(
          widget.event!.id,
          title: title,
          notes: notes,
          allDay: _allDay,
          occurrenceDate: scopeOccurrenceDate ?? _formatDateISO(_startDate),
          startTime: _allDay ? null : _formatTimeStr(_startTime),
          endTime: _allDay ? null : _formatTimeStr(_endTime),
          clearStartTime: _allDay,
          clearEndTime: _allDay,
          startDate: _formatDateISO(_startDate),
          endDate: _formatDateISO(_endDate),
          recurrenceType: _recurrence == RecurrenceType.none
              ? null
              : _recurrence.name,
          clearRecurrence: _recurrence == RecurrenceType.none,
          recurrenceInterval: _recurrenceInterval,
          recurrenceDays: recurrenceDays,
          recurrenceEnd:
              _recurrenceEnd != null ? _formatDateISO(_recurrenceEnd!) : null,
          reminderMinutesBefore: _reminderMinutes,
          clearReminder: _reminderMinutes == null,
          scope: scope,
        );
        invalidateAllFamilyInstances(ref, eventsProvider);
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final created = await repo.createEvent(
          calendarId: _selectedCalendar!.id,
          title: title.isNotEmpty ? title : null,
          notes: notes.isNotEmpty ? notes : null,
          allDay: _allDay,
          occurrenceDate: _formatDateISO(_startDate),
          startTime: _allDay ? null : _formatTimeStr(_startTime),
          endTime: _allDay ? null : _formatTimeStr(_endTime),
          startDate: _formatDateISO(_startDate),
          endDate: _formatDateISO(_endDate),
          recurrenceType:
              _recurrence == RecurrenceType.none ? null : _recurrence.name,
          recurrenceInterval: _recurrenceInterval,
          recurrenceDays: recurrenceDays,
          recurrenceEnd:
              _recurrenceEnd != null ? _formatDateISO(_recurrenceEnd!) : null,
          reminderMinutesBefore: _reminderMinutes,
        );
        invalidateAllFamilyInstances(ref, eventsProvider);
        if (mounted) Navigator.of(context).pop(created);
      }
    } on CalendarApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  void _delete() async {
    final event = widget.event!;

    String? scope;
    String? occurrenceDate;

    if (event.isRecurring) {
      // Recurring: ask scope instead of simple confirm.
      final chosen = await showScopeDialog(context, action: 'excluir');
      if (chosen == null || !mounted) return; // cancelled
      scope = switch (chosen) {
        RecurrenceScope.this_ => 'this',
        RecurrenceScope.thisAndFuture => 'this_and_future',
        RecurrenceScope.all => 'all',
      };
      if (chosen == RecurrenceScope.this_ ||
          chosen == RecurrenceScope.thisAndFuture) {
        occurrenceDate = _formatDateISO(event.occurrenceDate);
      }
    } else {
      // Non-recurring: simple confirm.
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BmoColors.screenBgElevated,
          title: const Text(
            'Excluir evento?',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 13,
              color: BmoColors.textPrimary,
            ),
          ),
          content: const Text(
            'Esta ação não pode ser desfeita.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style:
                  TextButton.styleFrom(foregroundColor: BmoColors.accentRed),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final repo = ref.read(calendarRepositoryProvider);

    try {
      await repo.deleteEvent(
        event.id,
        scope: scope,
        occurrenceDate: occurrenceDate,
      );
      invalidateAllFamilyInstances(ref, eventsProvider);
      if (mounted) Navigator.of(context).pop(null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }
}

class _FormLoading extends StatelessWidget {
  const _FormLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

class _FormError extends StatelessWidget {
  const _FormError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Erro ao carregar calendários',
          style: TextStyle(color: BmoColors.textMuted)),
    );
  }
}
