import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../home_devices/data/device.dart';
import '../../home_devices/data/device_alarm.dart';
import '../../home_devices/providers/alarms_providers.dart';
import '../../home_devices/providers/devices_providers.dart';

/// Card de luzes da casa.
///
/// Mostra switches inline para ligar/desligar cada luz (até 4),
/// contagem compacta no topo, e próximo alarme de luz no rodapé.
/// Toque no card navega para /casa.
class LightsCard extends ConsumerWidget {
  const LightsCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final pendingToggles = ref.watch(pendingTogglesProvider);
    // Alarme é opcional — erro/loading nunca derruba o card.
    final alarms = ref.watch(alarmsProvider).valueOrNull ?? const [];

    return devicesAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (devices) => _LightsContent(
        devices: devices,
        accent: accent,
        pendingToggles: pendingToggles,
        alarms: alarms,
      ),
    );
  }
}

// ============================================================
// Conteúdo principal
// ============================================================

class _LightsContent extends ConsumerWidget {
  const _LightsContent({
    required this.devices,
    required this.accent,
    required this.pendingToggles,
    required this.alarms,
  });

  final Map<String, LightDevice> devices;
  final Color accent;
  final Set<String> pendingToggles;
  final List<DeviceAlarm> alarms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = devices.entries.toList();
    final total = entries.length;
    final onCount =
        entries.where((e) => e.value.state == LightState.on).length;

    if (total == 0) return const _EmptyState();

    final nextAlarm = _findNextLightAlarm(alarms);
    const maxToShow = 4;
    final overflow = total > maxToShow ? total - maxToShow : 0;
    final visibleEntries = entries.take(maxToShow).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Cabeçalho compacto: ícone + "N de M acesas"
        _HeaderRow(onCount: onCount, total: total, accent: accent),
        const SizedBox(height: 10),
        // Linhas de luz com switch
        ...visibleEntries.map(
          (entry) => _LightRow(
            key: ValueKey(entry.key),
            name: entry.key,
            device: entry.value,
            accent: accent,
            isPending: pendingToggles.contains(entry.key),
            onToggle: () =>
                ref.read(devicesProvider.notifier).toggle(entry.key),
          ),
        ),
        // Indicador de overflow
        if (overflow > 0) _OverflowLabel(count: overflow),
        // Próximo alarme
        if (nextAlarm != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Divider(height: 1, color: BmoColors.screenBgElevated),
          ),
          const SizedBox(height: 10),
          _AlarmRow(alarm: nextAlarm),
        ],
      ],
    );
  }
}

// ============================================================
// Sub-widgets
// ============================================================

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.onCount,
    required this.total,
    required this.accent,
  });

  final int onCount;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lightbulb_outline, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          '$onCount de $total acesas',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: BmoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Uma linha com nome da luz + Switch.
///
/// O [Switch] consome o gesto de toque por padrão (HitTestBehavior.opaque
/// interno), então tocar nele não borbulha para o InkWell do DashCard.
class _LightRow extends StatelessWidget {
  const _LightRow({
    super.key,
    required this.name,
    required this.device,
    required this.accent,
    required this.isPending,
    required this.onToggle,
  });

  final String name;
  final LightDevice device;
  final Color accent;
  final bool isPending;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isOn = device.state == LightState.on;

    return Opacity(
      opacity: isPending ? 0.6 : 1.0,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: BmoColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: isOn,
              onChanged: isPending ? null : (_) => onToggle(),
              activeTrackColor: accent.withValues(alpha: 0.5),
              inactiveTrackColor: BmoColors.screenBgElevated,
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return accent;
                return BmoColors.textMuted;
              }),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowLabel extends StatelessWidget {
  const _OverflowLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '+$count mais',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: BmoColors.textMuted,
        ),
      ),
    );
  }
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow({required this.alarm});

  final DeviceAlarm alarm;

  @override
  Widget build(BuildContext context) {
    final isOff = alarm.targetState?.toUpperCase() == 'OFF';
    final action = isOff ? 'apagar' : 'acender';
    final deviceName = alarm.deviceName ?? 'luz';
    final time = alarm.dueTime ?? '--:--';
    final dayPart = _formatDay(alarm.dueDate);

    final label = dayPart != null
        ? '$action $deviceName $dayPart às $time'
        : '$action $deviceName às $time';

    return Row(
      children: [
        Icon(Icons.alarm, size: 14, color: BmoColors.accentYellow),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Estados especiais
// ============================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'carregando...',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: BmoColors.textMuted,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'nenhuma luz',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: BmoColors.textMuted,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: BmoColors.textMuted),
          SizedBox(width: 8),
          Text(
            'sem conexão',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Helpers
// ============================================================

const _weekdays = [
  '', // 0 — não usado
  'na segunda',
  'na terça',
  'na quarta',
  'na quinta',
  'na sexta',
  'no sábado',
  'no domingo',
];

/// Formata o [DateTime] como dia da semana em português: "na quinta", "no sábado".
/// Retorna null se a data for nula.
String? _formatDay(DateTime? date) {
  if (date == null) return null;
  final wd = date.weekday;
  if (wd < 1 || wd > 7) return null;
  return _weekdays[wd];
}

/// Combina [date] + [time] ("HH:MM") em um DateTime.
DateTime? _combineAlarmDateTime(DateTime? date, String? time) {
  if (date == null || time == null) return null;
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Encontra o próximo alarme de luz habilitado.
///
/// 1. Filtra por [DeviceAlarmActionType.light] && enabled.
/// 2. Combina dueDate + dueTime num DateTime e pega o mais próximo no futuro.
/// 3. Fallback: se nenhum futuro, ordena por (dueDate, dueTime) ascendente
///    e retorna o primeiro.
DeviceAlarm? _findNextLightAlarm(List<DeviceAlarm> alarms) {
  final lightAlarms =
      alarms
          .where((a) => a.actionType == DeviceAlarmActionType.light && a.enabled)
          .toList();
  if (lightAlarms.isEmpty) return null;

  final now = DateTime.now();
  DeviceAlarm? next;
  DateTime? nextTime;

  for (final alarm in lightAlarms) {
    final dt = _combineAlarmDateTime(alarm.dueDate, alarm.dueTime);
    if (dt == null) continue;
    if (dt.isAfter(now) && (nextTime == null || dt.isBefore(nextTime))) {
      next = alarm;
      nextTime = dt;
    }
  }

  if (next != null) return next;

  // Fallback: nenhum alarme futuro — pega o primeiro por data/hora.
  lightAlarms.sort((a, b) {
    final aDate = a.dueDate ?? DateTime(9999);
    final bDate = b.dueDate ?? DateTime(9999);
    final cmp = aDate.compareTo(bDate);
    if (cmp != 0) return cmp;
    return (a.dueTime ?? '').compareTo(b.dueTime ?? '');
  });
  return lightAlarms.first;
}
