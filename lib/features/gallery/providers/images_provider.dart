import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/identity/identity_state.dart';
import '../data/images_client.dart';
import '../data/images_repository.dart';
import '../data/image_model.dart';

part 'images_provider.g.dart';

// ============================================================
// Infraestrutura
// ============================================================

final imagesClientProvider = Provider<ImagesClient>((ref) {
  return ImagesClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

final imagesRepositoryProvider = Provider<ImagesRepository>((ref) {
  return ImagesRepository(ref.watch(imagesClientProvider));
});

// ============================================================
// Filtro de modo
// ============================================================

/// Modo selecionado no SegmentedButton da galeria.
/// `null` ou vazio = todos os modos.
final imageModeFilterProvider = StateProvider<String?>((ref) => null);

/// Raw image bytes for a given image [id], fetched from
/// GET /api/v1/images/{id}/file with X-User-Id header.
///
/// Family keyed by image id — Riverpod caches each result while at least
/// one watcher is active, so the thumbnail survives dashboard rebuilds.
final imageBytesProvider = FutureProvider.family<Uint8List, int>((ref, id) {
  final repo = ref.watch(imagesRepositoryProvider);
  return repo.fetchImageBytes(id);
});

// ============================================================
// Lista de imagens
// ============================================================

@riverpod
class Images extends _$Images {
  @override
  Future<List<GalleryImage>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final mode = ref.watch(imageModeFilterProvider);
    final repo = ref.watch(imagesRepositoryProvider);
    return repo.list(mode: mode);
  }

  /// Delete an image and remove it from the local list optimistically.
  Future<void> deleteImage(int id) async {
    final repo = ref.read(imagesRepositoryProvider);
    await repo.delete(id);
    final current = state.valueOrNull ?? const <GalleryImage>[];
    state = AsyncData(current.where((img) => img.id != id).toList());
  }

  /// Force a re-fetch (used by pull-to-refresh).
  Future<void> refresh() async {
    final mode = ref.read(imageModeFilterProvider);
    final repo = ref.read(imagesRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.list(mode: mode));
  }

  /// Set the mode filter and re-fetch.
  void setMode(String? mode) {
    ref.read(imageModeFilterProvider.notifier).state = mode;
  }
}
