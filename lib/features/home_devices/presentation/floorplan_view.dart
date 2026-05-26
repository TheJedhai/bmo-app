import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/device.dart';
import '../providers/devices_providers.dart';
import '../providers/ui_providers.dart';

class FloorplanView extends ConsumerStatefulWidget {
  const FloorplanView({super.key});

  @override
  ConsumerState<FloorplanView> createState() => _FloorplanViewState();
}

class _FloorplanViewState extends ConsumerState<FloorplanView> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    final image = Image.asset('assets/floorplan.png');
    image.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener((ImageInfo info, bool _) {
            if (mounted) {
              setState(() {
                _imageSize = Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                );
              });
            }
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final devicesAsync = ref.watch(devicesProvider);
    final positionsAsync = ref.watch(devicePositionsProvider);
    final editMode = ref.watch(editModeProvider);

    final devices = devicesAsync.valueOrNull ?? {};
    final positions = positionsAsync.valueOrNull ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final containerW = constraints.maxWidth;
        final containerH = constraints.maxHeight;
        final imageAspect = _imageSize!.width / _imageSize!.height;
        final containerAspect = containerW / containerH;

        final double renderW, renderH;
        if (containerAspect > imageAspect) {
          renderH = containerH;
          renderW = renderH * imageAspect;
        } else {
          renderW = containerW;
          renderH = renderW / imageAspect;
        }

        final offsetX = (containerW - renderW) / 2;
        final offsetY = (containerH - renderH) / 2;

        return Stack(
          children: [
            Center(
              child: SizedBox(
                width: renderW,
                height: renderH,
                child: Image.asset('assets/floorplan.png', fit: BoxFit.fill),
              ),
            ),
            for (final entry in devices.entries)
              Positioned(
                left: offsetX +
                    (positions[entry.key]?.x ?? 50) / 100 * renderW -
                    22,
                top: offsetY +
                    (positions[entry.key]?.y ?? 50) / 100 * renderH -
                    22,
                child: _DeviceDot(
                  device: entry.value,
                  editMode: editMode,
                  isDragging: false,
                  onTap: () =>
                      ref.read(devicesProvider.notifier).toggle(entry.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DeviceDot extends StatelessWidget {
  final LightDevice device;
  final bool editMode;
  final bool isDragging;
  final VoidCallback onTap;

  const _DeviceDot({
    required this.device,
    required this.editMode,
    required this.isDragging,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = device.state == LightState.on;

    return GestureDetector(
      onTap: editMode ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isOn ? BmoColors.accentYellow : BmoColors.screenBgElevated,
          shape: BoxShape.circle,
          border: Border.all(
            color: isOn
                ? BmoColors.accentYellow
                : BmoColors.screenBgElevated,
            width: 2,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: BmoColors.accentYellow.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isOn ? Icons.lightbulb : Icons.lightbulb_outline,
          size: 22,
          color: isOn ? BmoColors.screenBg : BmoColors.textMuted,
        ),
      ),
    );
  }
}
