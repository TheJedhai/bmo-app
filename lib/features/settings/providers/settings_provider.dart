import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/flux_model.dart';
import '../data/settings_client.dart';
import '../data/settings_repository.dart';

part 'settings_provider.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final settingsClientProvider = Provider<SettingsClient>((ref) {
  return SettingsClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(settingsClientProvider));
});

// ============================================================
// Modelos de imagem (dropdown)
// ============================================================

final imageModelsProvider = FutureProvider<List<FluxModel>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(settingsRepositoryProvider).getImageModels();
});

// ============================================================
// Mapa de settings
// ============================================================

@riverpod
class Settings extends _$Settings {
  @override
  Future<Map<String, String>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const {};
    return ref.watch(settingsRepositoryProvider).getAll();
  }

  /// Patch a single setting key and replace local state with server response.
  Future<void> updateSetting(String key, String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    final updated = await repo.patch({key: value});
    state = AsyncData(updated);
  }

  /// Force a re-fetch (used when re-opening the modal).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(settingsRepositoryProvider).getAll(),
    );
  }
}
