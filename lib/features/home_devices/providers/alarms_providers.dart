import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../data/alarms_client.dart';
import '../data/device_alarm.dart';
import '../data/scene.dart';

part 'alarms_providers.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final alarmsClientProvider = Provider<AlarmsClient>((ref) {
  return AlarmsClient(
    client: createHttpClient(),
    baseUrl: Env.bmoServerUrl,
  );
});

// ============================================================
// Scenes (read-only, loaded once)
// ============================================================

@riverpod
Future<List<Scene>> scenes(ScenesRef ref) async {
  final client = ref.read(alarmsClientProvider);
  return client.listScenes();
}

// ============================================================
// Alarms
// ============================================================

/// Alias curto para o provider gerado automaticamente.
final alarmsProvider = alarmsNotifierProvider;

@riverpod
class AlarmsNotifier extends _$AlarmsNotifier {
  @override
  Future<List<DeviceAlarm>> build() async {
    final client = ref.read(alarmsClientProvider);
    return client.list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final client = ref.read(alarmsClientProvider);
    state = await AsyncValue.guard(() => client.list());
  }

  Future<DeviceAlarm> create({
    required String name,
    required String dueDate,
    required String dueTime,
    String? recurrenceType,
    List<int>? recurrenceDays,
    required String actionType,
    String? deviceName,
    String? targetState,
    int? sceneId,
  }) async {
    final client = ref.read(alarmsClientProvider);
    final alarm = await client.create(
      name: name,
      dueDate: dueDate,
      dueTime: dueTime,
      recurrenceType: recurrenceType,
      recurrenceDays: recurrenceDays,
      actionType: actionType,
      deviceName: deviceName,
      targetState: targetState,
      sceneId: sceneId,
    );
    final current = state.valueOrNull ?? const <DeviceAlarm>[];
    state = AsyncData([...current, alarm]);
    return alarm;
  }

  Future<DeviceAlarm> editAlarm(
    int id, {
    String? name,
    bool? enabled,
    String? dueDate,
    String? dueTime,
    String? recurrenceType,
    List<int>? recurrenceDays,
    bool clearRecurrence = false,
    String? actionType,
    String? deviceName,
    bool clearDeviceName = false,
    String? targetState,
    bool clearTargetState = false,
    int? sceneId,
    bool clearSceneId = false,
  }) async {
    final client = ref.read(alarmsClientProvider);
    final updated = await client.update(
      id,
      name: name,
      enabled: enabled,
      dueDate: dueDate,
      dueTime: dueTime,
      recurrenceType: recurrenceType,
      recurrenceDays: recurrenceDays,
      clearRecurrence: clearRecurrence,
      actionType: actionType,
      deviceName: deviceName,
      clearDeviceName: clearDeviceName,
      targetState: targetState,
      clearTargetState: clearTargetState,
      sceneId: sceneId,
      clearSceneId: clearSceneId,
    );
    final current = state.valueOrNull ?? const <DeviceAlarm>[];
    state = AsyncData([
      for (final a in current)
        if (a.id == id) updated else a,
    ]);
    return updated;
  }

  Future<void> delete(int id) async {
    final client = ref.read(alarmsClientProvider);
    await client.delete(id);
    final current = state.valueOrNull ?? const <DeviceAlarm>[];
    state = AsyncData(current.where((a) => a.id != id).toList());
  }

  Future<void> toggleEnabled(int id) async {
    final current = state.valueOrNull ?? const <DeviceAlarm>[];
    final alarm = current.firstWhere((a) => a.id == id);
    await editAlarm(id, enabled: !alarm.enabled);
  }
}
