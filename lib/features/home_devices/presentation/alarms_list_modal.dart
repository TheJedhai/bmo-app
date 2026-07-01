import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../missions/data/models/task.dart';
import '../data/alarms_client.dart';
import '../data/device_alarm.dart';
import '../data/scene.dart';
import '../providers/alarms_providers.dart';
import 'alarm_form_modal.dart';

class AlarmsListModal extends ConsumerStatefulWidget {
  const AlarmsListModal({super.key});

  @override
  ConsumerState<AlarmsListModal> createState() => _AlarmsListModalState();
}

class _AlarmsListModalState extends ConsumerState<AlarmsListModal> {
  @override
  Widget build(BuildContext context) {
    final alarmsAsync = ref.watch(alarmsProvider);
    final scenesAsync = ref.watch(scenesProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: BmoColors.screenBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 480,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _Header(
              onAdd: () => _openForm(null),
            ),
            // Content
            Flexible(
              child: alarmsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => _AlarmsErrorState(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(alarmsProvider),
                ),
                data: (alarms) {
                  if (alarms.isEmpty) {
                    return const _AlarmsEmptyState();
                  }

                  final scenes =
                      scenesAsync.valueOrNull ?? const <Scene>[];

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: alarms.length,
                    itemBuilder: (_, i) => _AlarmItem(
                      alarm: alarms[i],
                      scenes: scenes,
                      onToggle: () => ref
                          .read(alarmsProvider.notifier)
                          .toggleEnabled(alarms[i].id),
                      onEdit: () => _openForm(alarms[i]),
                      onDelete: () =>
                          _confirmDelete(alarms[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(DeviceAlarm? alarm) {
    showDialog(
      context: context,
      builder: (_) => AlarmFormModal(alarm: alarm),
    ).then((_) {
      if (mounted) ref.invalidate(alarmsProvider);
    });
  }

  Future<void> _confirmDelete(DeviceAlarm alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text(
          'Deletar alarme?',
          style:
              TextStyle(color: BmoColors.textPrimary, fontSize: 14),
        ),
        content: Text(
          "Deletar '${alarm.name}'?",
          style: const TextStyle(
              color: BmoColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deletar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(alarmsProvider.notifier).delete(alarm.id);
      } on AlarmsApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

// ============================================================
// Header
// ============================================================

class _Header extends StatelessWidget {
  final VoidCallback onAdd;

  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          const Text(
            'Alarmes',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 12,
              color: BmoColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add, color: BmoColors.accentGreen),
            tooltip: 'Novo alarme',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon:
                const Icon(Icons.close, color: BmoColors.textMuted, size: 20),
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Empty state
// ============================================================

class _AlarmsEmptyState extends StatelessWidget {
  const _AlarmsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.alarm_off,
              size: 48,
              color: BmoColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum alarme configurado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: BmoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para criar um alarme que\n'
              'liga ou desliga dispositivos automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Error state
// ============================================================

class _AlarmsErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _AlarmsErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: BmoColors.textMuted),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(
                'Tentar novamente',
                style: TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Alarm item
// ============================================================

class _AlarmItem extends StatelessWidget {
  final DeviceAlarm alarm;
  final List<Scene> scenes;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AlarmItem({
    required this.alarm,
    required this.scenes,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: alarm.enabled ? 1.0 : 0.5,
      child: Card(
        color: BmoColors.screenBgElevated,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: BmoColors.screenBgElevated),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Alarm icon + name + details
              const Icon(Icons.alarm, size: 20, color: BmoColors.accentYellow),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarm.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BmoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSubtitle(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: BmoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle
              Switch(
                value: alarm.enabled,
                onChanged: (_) => onToggle(),
                activeThumbColor: BmoColors.accentYellow,
                activeTrackColor:
                    BmoColors.accentYellow.withValues(alpha: 0.4),
              ),
              // 3-dot menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: BmoColors.textMuted),
                color: BmoColors.screenBgElevated,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                      value: 'delete', child: Text('Deletar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];

    // Time
    if (alarm.dueTime != null) {
      parts.add(alarm.dueTime!);
    }

    // Recurrence summary
    final recurrence = _recurrenceSummary();
    if (recurrence.isNotEmpty) {
      parts.add(recurrence);
    }

    // Action
    final action = _actionSummary();
    if (action.isNotEmpty) {
      parts.add(action);
    }

    return parts.join(' · ');
  }

  String _recurrenceSummary() {
    final type = alarm.recurrenceType;
    final days = alarm.recurrenceDays;

    if (type == null) {
      if (alarm.dueDate != null) {
        return 'Uma vez em ${_formatShortDate(alarm.dueDate!)}';
      }
      return '';
    }

    return switch (type) {
      RecurrenceType.daily => 'Todo dia',
      RecurrenceType.weekly =>
        _weeklyLabel(days ?? <int>[]),
      RecurrenceType.monthly =>
        _monthlyLabel(days ?? <int>[]),
    };
  }

  String _weeklyLabel(List<int> days) {
    if (days.isEmpty) return 'Semanal';
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return days.map((d) => labels[d - 1]).join('/');
  }

  String _monthlyLabel(List<int> days) {
    if (days.isEmpty) return 'Mensal';
    if (days.length == 1) return 'Dia ${days.first} do mês';
    return 'Dias ${days.join(', ')}';
  }

  String _actionSummary() {
    return switch (alarm.actionType) {
      DeviceAlarmActionType.light =>
        alarm.targetState == 'ON'
            ? 'Ligar ${alarm.deviceName ?? 'dispositivo'}'
            : 'Desligar ${alarm.deviceName ?? 'dispositivo'}',
      DeviceAlarmActionType.scene =>
        _sceneName(),
    };
  }

  String _sceneName() {
    if (alarm.sceneId == null) return 'Cena';
    final scene = scenes.firstWhere(
      (s) => s.id == alarm.sceneId,
      orElse: () => const Scene(id: 0, name: 'Cena'),
    );
    return scene.name;
  }
}

String _formatShortDate(DateTime date) {
  const months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
