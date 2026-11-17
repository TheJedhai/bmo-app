import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/routines_client.dart';
import '../providers/routines_providers.dart';

/// Seção "Rotinas e avisos" das Configurações: horários, cidade do tempo,
/// seções do bom dia e gatilhos ligados/desligados.
class RoutinesSettingsSection extends ConsumerWidget {
  const RoutinesSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(routineConfigProvider);
    final triggersAsync = ref.watch(triggersProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          configAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorRow(
              error: error,
              onRetry: () => ref.read(routineConfigProvider.notifier).refresh(),
            ),
            data: (config) => _ConfigContent(config: config),
          ),
          const SizedBox(height: 24),
          Text(
            'Gatilhos',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: BmoColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Frases, horários e eventos que acordam o BMO.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          triggersAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorRow(
              error: error,
              onRetry: () => ref.read(triggersProvider.notifier).refresh(),
            ),
            data: (triggers) => Column(
              children: [
                for (final trigger in triggers) _TriggerTile(trigger: trigger),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigContent extends ConsumerStatefulWidget {
  final RoutineSettings config;

  const _ConfigContent({required this.config});

  @override
  ConsumerState<_ConfigContent> createState() => _ConfigContentState();
}

class _ConfigContentState extends ConsumerState<_ConfigContent> {
  late final TextEditingController _place = TextEditingController(
    text: widget.config.weatherPlace,
  );
  late final TextEditingController _lat = TextEditingController(
    text: '${widget.config.weatherLat}',
  );
  late final TextEditingController _lon = TextEditingController(
    text: '${widget.config.weatherLon}',
  );
  bool _savingWeather = false;
  String? _weatherError;

  /// Seções do bom dia, na ordem fixa do contrato.
  static const _sectionLabels = <String, String>{
    'missions': 'Missões',
    'weather': 'Tempo',
    'events': 'Agenda',
    'news': 'Notícias',
    'coding': 'Coding',
    'email': 'E-mail',
    'health': 'Saúde',
    'spend': 'Gastos',
    'held': 'Seguradas',
  };

  @override
  void didUpdateWidget(covariant _ConfigContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Config nova do servidor (PATCH devolve a versão efetiva).
    if (oldWidget.config.weatherPlace != widget.config.weatherPlace) {
      _place.text = widget.config.weatherPlace;
    }
    if (oldWidget.config.weatherLat != widget.config.weatherLat) {
      _lat.text = '${widget.config.weatherLat}';
    }
    if (oldWidget.config.weatherLon != widget.config.weatherLon) {
      _lon.text = '${widget.config.weatherLon}';
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  Future<void> _patchTime(String key, String current) async {
    final initial = _parseHour(current);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    try {
      await ref.read(routineConfigProvider.notifier).patch({key: value});
    } catch (e) {
      _snack('falha ao salvar: $e');
    }
  }

  Future<void> _saveWeather() async {
    setState(() {
      _savingWeather = true;
      _weatherError = null;
    });
    try {
      await ref.read(routineConfigProvider.notifier).patch({
        'weather_place': _place.text.trim(),
        'weather_lat': double.tryParse(_lat.text.trim()),
        'weather_lon': double.tryParse(_lon.text.trim()),
      });
    } catch (e) {
      if (mounted) setState(() => _weatherError = 'falha ao salvar: $e');
    } finally {
      if (mounted) setState(() => _savingWeather = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static TimeOfDay _parseHour(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 4;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Horários',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BmoColors.textPrimary),
        ),
        const SizedBox(height: 8),
        _HourRow(
          label: 'Virada do dia',
          value: config.dayRoll,
          onTap: () => _patchTime('day_roll', config.dayRoll),
        ),
        _HourRow(
          label: 'Saída do silêncio',
          value: config.quietEnd,
          onTap: () => _patchTime('quiet_end', config.quietEnd),
        ),
        const SizedBox(height: 20),
        Text(
          'Cidade do tempo',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BmoColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _place,
          decoration: const InputDecoration(
            labelText: 'nome da cidade',
            isDense: true,
          ),
          style: const TextStyle(
            fontFamily: 'Inter',
            color: BmoColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'latitude',
                  isDense: true,
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: BmoColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lon,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'longitude',
                  isDense: true,
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: BmoColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingWeather ? null : _saveWeather,
            style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentGreen,
              foregroundColor: const Color(0xFF0F1115),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Salvar cidade'),
          ),
        ),
        if (_weatherError != null)
          Text(
            _weatherError!,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.accentRed,
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Seções do bom dia',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: BmoColors.textPrimary),
        ),
        const SizedBox(height: 4),
        for (final entry in _sectionLabels.entries)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              entry.value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: BmoColors.textPrimary,
              ),
            ),
            value: config.sections[entry.key] ?? true,
            activeThumbColor: BmoColors.accentGreen,
            onChanged: (enabled) async {
              try {
                await ref.read(routineConfigProvider.notifier).patch({
                  'sections': {entry.key: enabled},
                });
              } catch (e) {
                _snack('falha ao salvar: $e');
              }
            },
          ),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HourRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: BmoColors.textPrimary,
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: BmoColors.accentGreen,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _TriggerTile extends ConsumerWidget {
  final RoutineTrigger trigger;

  const _TriggerTile({required this.trigger});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = [
      if (trigger.schedule != null) trigger.schedule!,
      if (trigger.event != null) trigger.event!,
      if (trigger.phrases.isNotEmpty) trigger.phrases.join(', '),
    ].join(' · ');

    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        trigger.description,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: BmoColors.textPrimary,
        ),
      ),
      subtitle: detail.isEmpty
          ? null
          : Text(
              detail,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted,
              ),
            ),
      value: trigger.enabled,
      activeThumbColor: BmoColors.accentGreen,
      onChanged: (enabled) async {
        try {
          await ref
              .read(triggersProvider.notifier)
              .setEnabled(trigger.key, enabled);
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('falha ao salvar: $e')));
        }
      },
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorRow({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'falha ao carregar: $error',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.accentRed,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('tentar de novo')),
      ],
    );
  }
}
