import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../data/device.dart';
import '../data/devices_client.dart';
import '../data/devices_ws_client.dart';

part 'devices_providers.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final devicesClientProvider = Provider<DevicesClient>((ref) {
  return DevicesClient(
    client: createHttpClient(),
    baseUrl: Env.bmoServerUrl,
  );
});

final devicesWsClientProvider = Provider<DevicesWsClient>((ref) {
  return DevicesWsClient(baseUrl: Env.bmoServerUrl);
});

// ============================================================
// Pending toggles
// ============================================================

final pendingTogglesProvider = StateProvider<Set<String>>((ref) => {});

// ============================================================
// Devices
// ============================================================

@riverpod
class Devices extends _$Devices {
  StreamSubscription<DeviceWsMessage>? _wsSubscription;

  @override
  Future<Map<String, LightDevice>> build() async {
    final client = ref.read(devicesClientProvider);
    final lights = await client.listLights();
    final map = <String, LightDevice>{
      for (final l in lights) l['name'] as String: LightDevice.fromJson(l),
    };

    _startWsListener();

    ref.onDispose(() {
      _wsSubscription?.cancel();
    });

    return map;
  }

  void _startWsListener() {
    _wsSubscription?.cancel();
    _runWsLoop();
  }

  Future<void> _runWsLoop() async {
    final wsClient = ref.read(devicesWsClientProvider);
    var backoff = const Duration(seconds: 1);
    const maxBackoff = Duration(seconds: 30);

    while (true) {
      try {
        final stream = wsClient.connect();
        _wsSubscription = stream.listen(
          (msg) {
            _handleWsMessage(msg);
          },
          onError: (error) {
            debugPrint('Devices WS stream error: $error');
          },
        );
        // Stream ended cleanly — reset backoff and reconnect.
        backoff = const Duration(seconds: 1);
      } catch (e) {
        debugPrint(
            'Devices WS error: $e. Reconnecting in ${backoff.inSeconds}s...');
        await Future.delayed(backoff);
        backoff = backoff * 2;
        if (backoff > maxBackoff) backoff = maxBackoff;
      }
    }
  }

  void _handleWsMessage(DeviceWsMessage msg) {
    final current = state.valueOrNull ?? {};
    switch (msg) {
      case InitialState(:final lights):
        state = AsyncData({for (final l in lights) l.name: l});
      case StateUpdate(:final deviceName, :final newState):
        final device = current[deviceName];
        if (device == null) break;
        final lightState = switch (newState.toUpperCase()) {
          'ON' => LightState.on,
          'OFF' => LightState.off,
          _ => LightState.unknown,
        };
        state = AsyncData({
          ...current,
          deviceName: LightDevice(
            name: device.name,
            state: lightState,
            linkquality: device.linkquality,
            online: device.online,
          ),
        });
        ref.read(pendingTogglesProvider.notifier)
            .update((s) => s.difference({deviceName}));
    }
  }

  Future<void> toggle(String name) async {
    ref.read(pendingTogglesProvider.notifier).update((s) => {...s, name});
    try {
      await ref.read(devicesClientProvider).toggle(name);
    } on Exception {
      ref.read(pendingTogglesProvider.notifier)
          .update((s) => s.difference({name}));
      rethrow;
    }
    // Safety timeout: clear pending after 5s if no WS update received.
    Future.delayed(const Duration(seconds: 5), () {
      if (state.valueOrNull != null) {
        ref.read(pendingTogglesProvider.notifier)
            .update((s) => s.difference({name}));
      }
    });
  }
}
