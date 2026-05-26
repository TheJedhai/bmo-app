import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/device.dart';
import '../data/device_position.dart';
import '../providers/devices_providers.dart';
import '../providers/ui_providers.dart';

class FloorplanView extends ConsumerStatefulWidget {
  const FloorplanView({super.key});

  @override
  ConsumerState<FloorplanView> createState() => _FloorplanViewState();
}

class _FloorplanViewState extends ConsumerState<FloorplanView> {
  Size? _imageSize;

  // Drag state
  String? _dragDevice;
  double _dragX = 0;
  double _dragY = 0;

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

  double _toPercent(double deltaPx, double renderSize) =>
      deltaPx / renderSize * 100;

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
              _buildDeviceDot(
                name: entry.key,
                device: entry.value,
                storedPosition: positions[entry.key],
                editMode: editMode,
                offsetX: offsetX,
                offsetY: offsetY,
                renderW: renderW,
                renderH: renderH,
              ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceDot({
    required String name,
    required LightDevice device,
    DevicePosition? storedPosition,
    required bool editMode,
    required double offsetX,
    required double offsetY,
    required double renderW,
    required double renderH,
  }) {
    final isDragging = _dragDevice == name;
    final x = isDragging
        ? _dragX
        : (storedPosition?.x ?? 50);
    final y = isDragging
        ? _dragY
        : (storedPosition?.y ?? 50);

    final left = offsetX + x / 100 * renderW - 22;
    final top = offsetY + y / 100 * renderH - 22;

    Widget dot = _DeviceDot(
      device: device,
      editMode: editMode,
      isDragging: isDragging,
      onTap: () => ref.read(devicesProvider.notifier).toggle(name),
    );

    if (editMode) {
      dot = GestureDetector(
        onPanStart: (_) {
          setState(() {
            _dragDevice = name;
            _dragX = x;
            _dragY = y;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _dragX = (_dragX + _toPercent(details.delta.dx, renderW))
                .clamp(0.0, 100.0);
            _dragY = (_dragY + _toPercent(details.delta.dy, renderH))
                .clamp(0.0, 100.0);
          });
        },
        onPanEnd: (_) {
          final finalX = _dragX;
          final finalY = _dragY;
          setState(() => _dragDevice = null);
          ref
              .read(devicePositionsProvider.notifier)
              .setPosition(name, finalX, finalY);
        },
        child: dot,
      );
    }

    return Positioned(left: left, top: top, child: dot);
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
            color: isDragging
                ? BmoColors.accentGreen
                : isOn
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
