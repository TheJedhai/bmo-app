import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../../../core/platform/widget_refresh.dart';
import '../data/device.dart';
import '../data/devices_client.dart';
import '../data/devices_ws_client.dart';

part 'devices_providers.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final devicesClientProvider = Provider<DevicesClient>((ref) {
  return DevicesClient(
    client: ref.watch(httpClientProvider),
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
// WebSocket stream
// ============================================================

final devicesWsStreamProvider = StreamProvider<DeviceWsMessage>((ref) {
  final client = ref.read(devicesWsClientProvider);
  var backoff = const Duration(seconds: 1);
  const maxBackoff = Duration(seconds: 30);
  var cancelled = false;
  StreamSubscription<DeviceWsMessage>? connectionSub;
  Completer<void>? currentDone;

  late final StreamController<DeviceWsMessage> controller;
  controller = StreamController<DeviceWsMessage>(
    // Cancel síncrono: o invalidate cancela a conexão corrente ANTES de o
    // provider rebuildar — nunca duas conexões ao mesmo tempo.
    onCancel: () {
      cancelled = true;
      connectionSub?.cancel();
      currentDone?.complete();
    },
  );

  Future<void> run() async {
    while (!cancelled) {
      final done = currentDone = Completer<void>();
      try {
        connectionSub = client.connect().listen(
          (msg) {
            if (!controller.isClosed) controller.add(msg);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          },
        );
        await done.future;
        // Close limpo: volta imediato com backoff resetado.
        backoff = const Duration(seconds: 1);
      } catch (e) {
        if (cancelled) break;
        debugPrint(
            'Devices WS error: $e. Reconnecting in ${backoff.inSeconds}s...');
        await Future.delayed(backoff);
        backoff = backoff * 2;
        if (backoff > maxBackoff) backoff = maxBackoff;
      } finally {
        await connectionSub?.cancel();
        connectionSub = null;
      }
      if (cancelled) break;
    }
    await controller.close();
  }

  unawaited(run());
  return controller.stream;
});

// ============================================================
// Devices
// ============================================================

@riverpod
class Devices extends _$Devices {
  @override
  Future<Map<String, LightDevice>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};
    final client = ref.watch(devicesClientProvider);
    final lights = await client.listLights();
    final map = <String, LightDevice>{
      for (final l in lights) l['name'] as String: LightDevice.fromJson(l),
    };

    ref.listen(devicesWsStreamProvider, (prev, next) {
      next.when(
        data: _handleWsMessage,
        error: (error, _) => debugPrint('Devices WS stream error: $error'),
        loading: () {},
      );
    });

    return map;
  }

  void _handleWsMessage(DeviceWsMessage msg) {
    final current = state.valueOrNull ?? {};
    switch (msg) {
      case InitialState(:final lights):
        state = AsyncData({for (final l in lights) l.name: l});
      case StateUpdate(:final deviceName, :final newState, :final linkquality):
        final device = current[deviceName];
        if (device == null) break;
        state = AsyncData({
          ...current,
          deviceName: LightDevice(
            name: device.name,
            state: newState,
            linkquality: linkquality,
            online: device.online,
          ),
        });
        ref.read(pendingTogglesProvider.notifier)
            .update((s) => s.difference({deviceName}));
        // Estado de luz mudou PELO APP (ou ecoa pro app): pede recarga do
        // widget. Debounced — rajada de StateUpdate não dispara dezenas de
        // recargas; vira uma após o silêncio.
        requestWidgetReload(debounced: true);
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
    Future.delayed(const Duration(seconds: 5), () {
      if (state.valueOrNull != null) {
        ref.read(pendingTogglesProvider.notifier)
            .update((s) => s.difference({name}));
      }
    });
  }
}

