import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/events/events_provider.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/routines_client.dart';
import '../data/routines_repository.dart';

part 'routines_providers.g.dart';

@riverpod
RoutinesRepository routinesRepository(RoutinesRepositoryRef ref) {
  return RoutinesRepository(
    RoutinesClient(
      client: ref.watch(httpClientProvider),
      baseUrl: Env.bmoServerUrl,
    ),
  );
}

// ============================================================
// Presença
// ============================================================

/// Presença atual. Relê na reconexão do SSE e na troca de perfil; não há
/// evento de presença no `/api/v1/stream` (o servidor não publica um).
@riverpod
class PresenceController extends _$PresenceController {
  @override
  Future<Presence> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.watch(sseGenerationProvider);
    if (userId == null) return const Presence(mode: PresenceMode.emCasa);
    return ref.watch(routinesRepositoryProvider).getPresence();
  }

  Future<void> set(PresenceMode mode, {DateTime? until}) async {
    final repo = ref.read(routinesRepositoryProvider);
    state = AsyncData(await repo.setPresence(mode, until: until));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routinesRepositoryProvider).getPresence(),
    );
  }
}

// ============================================================
// Notificações
// ============================================================

@riverpod
class Notifications extends _$Notifications {
  @override
  Future<List<AppNotification>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    ref.watch(sseGenerationProvider);
    if (userId == null) return const [];
    return ref.watch(routinesRepositoryProvider).listNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routinesRepositoryProvider).listNotifications(),
    );
  }
}

// ============================================================
// Configuração das rotinas
// ============================================================

@riverpod
class RoutineConfig extends _$RoutineConfig {
  @override
  Future<RoutineSettings> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const RoutineSettings(
        dayRoll: '04:00',
        quietEnd: '10:00',
        weatherLat: 0,
        weatherLon: 0,
        weatherPlace: '',
        sections: {},
      );
    }
    return ref.watch(routinesRepositoryProvider).getRoutineSettings();
  }

  Future<void> patch(Map<String, dynamic> patch) async {
    final repo = ref.read(routinesRepositoryProvider);
    state = AsyncData(await repo.patchRoutineSettings(patch));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routinesRepositoryProvider).getRoutineSettings(),
    );
  }
}

// ============================================================
// Gatilhos
// ============================================================

@riverpod
class Triggers extends _$Triggers {
  @override
  Future<List<RoutineTrigger>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.watch(routinesRepositoryProvider).listTriggers();
  }

  Future<void> setEnabled(String key, bool enabled) async {
    await ref.read(routinesRepositoryProvider).setTriggerEnabled(key, enabled);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final trigger in current)
        trigger.key == key ? trigger.copyWith(enabled: enabled) : trigger,
    ]);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routinesRepositoryProvider).listTriggers(),
    );
  }
}
