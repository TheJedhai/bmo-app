import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_tab.dart';
import '../../../core/navigation/tab_provider.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../home_devices/data/device.dart';
import '../../home_devices/providers/devices_providers.dart';

/// Card de luzes da casa — span 2×1.
///
/// Mostra "N de M luzes acesas" com ícone de lâmpada condicional
/// (accentYellow quando há luzes acesas, textMuted quando tudo apagado).
/// Toque navega para a aba Casa.
class LightsCard extends ConsumerWidget {
  const LightsCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return devicesAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (devices) => _LightsContent(devices: devices),
    );
  }
}

class _LightsContent extends ConsumerWidget {
  const _LightsContent({required this.devices});

  final Map<String, LightDevice> devices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = devices.length;
    final onCount =
        devices.values.where((d) => d.state == LightState.on).length;

    return InkWell(
      onTap: () =>
          ref.read(currentTabProvider.notifier).setTab(AppTab.homeDevices),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          // Ícone de lâmpada
          Icon(
            onCount > 0 ? Icons.lightbulb : Icons.lightbulb_outline,
            size: 36,
            color: onCount > 0 ? BmoColors.accentYellow : BmoColors.textMuted,
          ),
          const SizedBox(width: 16),
          // Contagem
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$onCount de $total',
                  style: const TextStyle(
                    fontFamily: 'PressStart2P',
                    fontSize: 20,
                    color: BmoColors.accentYellow,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'luzes acesas',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, size: 36, color: BmoColors.textMuted),
          SizedBox(width: 16),
          Text(
            '—',
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 20,
              color: BmoColors.textMuted,
            ),
          ),
        ],
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
          Icon(Icons.lightbulb_outline, size: 36, color: BmoColors.textMuted),
          SizedBox(width: 16),
          Text(
            'sem conexão',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
