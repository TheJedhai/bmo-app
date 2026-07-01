import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/device.dart';
import '../data/devices_client.dart';
import '../providers/devices_providers.dart';
import 'alarms_list_modal.dart';

class HomeDevicesScreen extends ConsumerWidget {
  const HomeDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _HeaderBar(
          onAlarmsTap: () => showDialog(
            context: context,
            builder: (_) => const AlarmsListModal(),
          ),
        ),
        const Expanded(child: _DeviceList()),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final VoidCallback onAlarmsTap;

  const _HeaderBar({required this.onAlarmsTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: onAlarmsTap,
            icon: const Icon(Icons.alarm, color: BmoColors.accentYellow),
            tooltip: 'Alarmes',
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);
    final pendingToggles = ref.watch(pendingTogglesProvider);

    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        error: error,
        onRetry: () => ref.invalidate(devicesProvider),
      ),
      data: (devices) {
        if (devices.isEmpty) return const _EmptyState();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return _DeviceGrid(
              devices: devices,
              pendingToggles: pendingToggles,
              isMobile: isMobile,
              onToggle: (name) =>
                  ref.read(devicesProvider.notifier).toggle(name),
            );
          },
        );
      },
    );
  }
}

class _DeviceGrid extends StatelessWidget {
  final Map<String, LightDevice> devices;
  final Set<String> pendingToggles;
  final bool isMobile;
  final void Function(String name) onToggle;

  const _DeviceGrid({
    required this.devices,
    required this.pendingToggles,
    required this.isMobile,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final entries = devices.entries.toList();

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entries.length,
        itemBuilder: (_, i) => _DeviceCard(
          name: entries[i].key,
          device: entries[i].value,
          isPending: pendingToggles.contains(entries[i].key),
          onToggle: onToggle,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3.5,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) => _DeviceCard(
        name: entries[i].key,
        device: entries[i].value,
        isPending: pendingToggles.contains(entries[i].key),
        onToggle: onToggle,
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final String name;
  final LightDevice device;
  final bool isPending;
  final void Function(String name) onToggle;

  const _DeviceCard({
    required this.name,
    required this.device,
    required this.isPending,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = device.state == LightState.on;

    return Opacity(
      opacity: isPending ? 0.6 : 1.0,
      child: Card(
        color: isOn
            ? BmoColors.screenBgElevated
            : BmoColors.screenBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isOn ? BmoColors.accentYellow : BmoColors.screenBgElevated,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isPending ? null : () => onToggle(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: isOn ? BmoColors.accentYellow : BmoColors.textMuted,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: BmoColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'sinal: ${(device.linkquality / 255 * 100).round()}%',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: BmoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isPending)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BmoColors.accentGreen,
                    ),
                  )
                else
                  Switch(
                    value: isOn,
                    onChanged: (_) => onToggle(name),
                    activeThumbColor: BmoColors.accentYellow,
                    activeTrackColor:
                        BmoColors.accentYellow.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.home_outlined,
              size: 64,
              color: BmoColors.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum dispositivo encontrado.\n'
              'Verifique se o broker MQTT está acessível.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: BmoColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {},
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

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  bool get _isMqttError => error is MqttUnavailableException;

  @override
  Widget build(BuildContext context) {
    if (_isMqttError) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.red.shade800,
            child: SafeArea(
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Broker MQTT indisponível — controles desativados',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Tentar novamente',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: BmoColors.textMuted),
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
