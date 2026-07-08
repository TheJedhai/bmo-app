import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home_devices/providers/alarms_providers.dart';
import '../../features/memories/providers/memories_provider.dart';
import '../../features/missions/data/missions_providers.dart';
import '../../features/gallery/providers/images_provider.dart';
import '../../features/rss/data/rss_providers.dart';
import '../config/env.dart';
import '../http/client_factory.dart';
import 'events_client.dart';
import 'rich_blocks_provider.dart';

final eventsClientProvider = Provider<EventsClient>((ref) {
  return EventsClient(
    client: ref.watch(httpClientProvider),
    baseUrl: Env.bmoServerUrl,
  );
});

/// Incremented on each SSE `connected` event so cards can detect reconnect
/// and re-sync any ephemeral state lost during the disconnection.
final sseGenerationProvider = StateProvider<int>((ref) => 0);

final eventsStreamProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final client = ref.read(eventsClientProvider);
  var backoff = const Duration(seconds: 1);
  const maxBackoff = Duration(seconds: 30);

  while (true) {
    try {
      yield* client.connect();
      // Clean disconnect — reset backoff and reconnect immediately.
      backoff = const Duration(seconds: 1);
    } catch (e) {
      debugPrint('SSE error: $e. Reconnecting in ${backoff.inSeconds}s...');
      await Future.delayed(backoff);
      backoff = backoff * 2;
      if (backoff > maxBackoff) backoff = maxBackoff;
    }
  }
});

final eventsListenerProvider = Provider<void>((ref) {
  ref.listen(eventsStreamProvider, (prev, next) {
    next.when(
      data: (event) => _handleEvent(ref, event),
      error: (error, _) => debugPrint('SSE stream error: $error'),
      loading: () {},
    );
  });
});

void _handleEvent(Ref ref, Map<String, dynamic> event) {
  final type = event['type'] as String?;
  if (type == null) return;

  switch (type) {
    // ---- Tasks ----
    case 'task.created':
    case 'task.updated':
    case 'task.deleted':
    case 'task.completed':
      _invalidateAllFamilyInstances(ref, tasksProvider);
    case 'folder.created':
    case 'folder.updated':
    case 'folder.deleted':
      ref.invalidate(foldersProvider);
      _invalidateAllFamilyInstances(ref, tasksProvider);
    case 'tasks.batch_updated':
      _invalidateAllFamilyInstances(ref, tasksProvider);

    // ---- Memories ----
    case 'memory.created':
    case 'memory.updated':
    case 'memory.deleted':
      ref.invalidate(memoriesProvider);

    // ---- RSS ----
    case 'article.created':
    case 'article.updated':
    case 'articles.batch_updated':
      _invalidateAllFamilyInstances(ref, articlesProvider);
      ref.invalidate(unreadCountProvider);
    case 'feed.created':
    case 'feed.updated':
      ref.invalidate(feedsProvider);
      _invalidateAllFamilyInstances(ref, articlesProvider);
    case 'feed.deleted':
      ref.invalidate(feedsProvider);
      _invalidateAllFamilyInstances(ref, articlesProvider);
      ref.invalidate(unreadCountProvider);

    // ---- Images ----
    case 'image.created':
    case 'image.updated':
    case 'image.completed':
    case 'image.failed':
      ref.invalidate(imagesProvider);

    // ---- Alarms ----
    case 'alarm.created':
    case 'alarm.updated':
    case 'alarm.deleted':
      ref.invalidate(alarmsProvider);

    // ---- Rich blocks (in-place patch, not invalidate) ----
    case 'rich.update':
      final blockId = event['block_id'] as String?;
      final patch = event['patch'] as Map<String, dynamic>?;
      if (blockId != null && patch != null) {
        ref.read(richBlocksProvider.notifier).applyPatch(blockId, patch);
      }

    case 'connected':
      debugPrint('SSE connected');
      ref.read(sseGenerationProvider.notifier).state++;
  }
}

/// Invalida todas as instâncias ativas de um provider `.family`.
///
/// Diferente de [Ref.invalidate] chamado diretamente na família — que pode não
/// forçar o rebuild de todas as instâncias vivas, especialmente com
/// `keepAlive: true` em [IndexedStack].
///
/// Percorre [ProviderContainer.getAllProviderElements] e invalida cada
/// instância cujo `origin.from` seja a família recebida, garantindo refetch
/// do backend em todos os widgets que a consomem.
void _invalidateAllFamilyInstances(Ref ref, Object family) {
  for (final element in ref.container.getAllProviderElements()) {
    if (element.origin.from == family) {
      ref.invalidate(element.origin);
    }
  }
}
