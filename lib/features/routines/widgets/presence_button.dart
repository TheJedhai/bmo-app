import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/dark_circle.dart';
import '../data/routines_client.dart';
import '../providers/routines_providers.dart';

/// Ícone do estado de presença no topo; toque abre as opções.
class PresenceButton extends ConsumerWidget {
  final double size;
  final double iconSize;

  const PresenceButton({super.key, this.size = 48, this.iconSize = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceControllerProvider).valueOrNull;
    final mode = presence?.mode ?? PresenceMode.emCasa;
    final until = presence?.until;

    return Tooltip(
      message: until == null
          ? 'presença: ${mode.label}'
          : 'presença: ${mode.label} até ${_hour(until)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showPresenceDialog(context),
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox.square(
            dimension: size,
            child: DarkCircle(
              diameter: size,
              child: Icon(
                iconForPresence(mode),
                size: iconSize,
                color: colorForPresence(mode),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData iconForPresence(PresenceMode mode) => switch (mode) {
  PresenceMode.emCasa => Icons.home_outlined,
  PresenceMode.fora => Icons.directions_walk,
  PresenceMode.vozSilenciada => Icons.volume_off_outlined,
  PresenceMode.noite => Icons.bedtime_outlined,
};

Color colorForPresence(PresenceMode mode) => switch (mode) {
  PresenceMode.emCasa => BmoColors.accentGreen,
  PresenceMode.fora => BmoColors.textSecondary,
  PresenceMode.vozSilenciada => BmoColors.accentYellow,
  PresenceMode.noite => BmoColors.accentBlue,
};

String _hour(DateTime time) => DateFormat('HH:mm').format(time.toLocal());

/// Opções de presença + "silêncio até…". Cada escolha vai por
/// `PUT /api/v1/notifications/presence`.
Future<void> showPresenceDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _PresenceDialog(),
  );
}

class _PresenceDialog extends ConsumerStatefulWidget {
  const _PresenceDialog();

  @override
  ConsumerState<_PresenceDialog> createState() => _PresenceDialogState();
}

class _PresenceDialogState extends ConsumerState<_PresenceDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _select(PresenceMode mode, {DateTime? until}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(presenceControllerProvider.notifier)
          .set(mode, until: until);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'falha ao trocar a presença: $e';
        });
      }
    }
  }

  Future<void> _pickSilenceUntil() async {
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (picked == null) return;
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    if (!target.isAfter(now)) target = target.add(const Duration(days: 1));
    await _select(PresenceMode.noite, until: target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presence = ref.watch(presenceControllerProvider).valueOrNull;
    final until = presence?.until;

    return AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      title: const Text('Presença'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final mode in PresenceMode.values)
              ListTile(
                enabled: !_busy,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  iconForPresence(mode),
                  color: colorForPresence(mode),
                ),
                title: Text(
                  mode.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: presence?.mode == mode
                        ? BmoColors.accentGreen
                        : BmoColors.textPrimary,
                  ),
                ),
                trailing: presence?.mode == mode
                    ? const Icon(
                        Icons.check,
                        size: 18,
                        color: BmoColors.accentGreen,
                      )
                    : null,
                onTap: () => _select(mode),
              ),
            if (until != null)
              Text(
                'atual até ${_hour(until)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
              ),
            const Divider(),
            ListTile(
              enabled: !_busy,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.schedule,
                color: BmoColors.accentYellow,
              ),
              title: Text(
                'silêncio até…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BmoColors.textPrimary,
                ),
              ),
              subtitle: Text(
                'segura tudo e entrega o resumo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textMuted,
                ),
              ),
              onTap: _pickSilenceUntil,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentRed,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
