import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../home_devices/data/device.dart';
import '../../home_devices/providers/devices_providers.dart';

/// Card de luzes da casa.
///
/// Mostra ícone de lâmpada grande em outline na cor do accent,
/// "N de M" em bold e "luzes acesas" em muted. Toque via DashCard onTap.
class LightsCard extends ConsumerWidget {
  const LightsCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider);

    return devicesAsync.when(
      loading: () => const _LoadingState(),
      error: (_, _) => const _ErrorState(),
      data: (devices) => _LightsContent(devices: devices, accent: accent),
    );
  }
}

class _LightsContent extends StatelessWidget {
  const _LightsContent({required this.devices, required this.accent});

  final Map<String, LightDevice> devices;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = devices.length;
    final onCount =
        devices.values.where((d) => d.state == LightState.on).length;

    return Row(
      children: [
        // Ícone de lâmpada grande em outline na cor do accent
        Icon(
          Icons.lightbulb_outline,
          size: 48,
          color: accent,
        ),
        const SizedBox(width: 16),
        // Contagem
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$onCount de $total',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: BmoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'luzes acesas',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textMuted,
              ),
            ),
          ],
        ),
      ],
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
          Icon(Icons.lightbulb_outline, size: 48, color: BmoColors.textMuted),
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
          Icon(Icons.lightbulb_outline, size: 48, color: BmoColors.textMuted),
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
