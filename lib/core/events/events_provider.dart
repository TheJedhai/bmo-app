import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home_devices/providers/alarms_providers.dart';
import '../../features/memories/providers/memories_provider.dart';
import '../../features/missions/data/missions_providers.dart';
import '../../features/calendar/data/calendar_providers.dart';
import '../../features/coding/data/coding_providers.dart';
import '../../features/finances/data/categorization_providers.dart';
import '../../features/gallery/providers/images_provider.dart';

import '../../features/rss/data/rss_providers.dart';
import '../config/env.dart';
import '../http/client_factory.dart';
import '../identity/identity_state.dart';
import '../utils/provider_utils.dart';
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

final eventsStreamProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  // Watch userId so the stream is invalidated and reconnects with the
  // new identity when the user switches profiles.
  final userId = ref.watch(currentUserIdProvider);

  // Guard: without an identity the SSE would 400 in a loop forever.
  // Return an empty stream — the provider is autoDispose, so it will be
  // recreated when _BmoMainShell mounts with a valid profile.
  if (userId == null) return;

  final client = ref.watch(eventsClientProvider);
  var backoff = const Duration(seconds: 1);
  const maxBackoff = Duration(seconds: 30);

  // Cancellation flag so the while(true) loop dies when the provider is
  // invalidated/disposed — never leave an orphan generator with backoff
  // running after a profile switch.
  var cancelled = false;
  ref.onDispose(() => cancelled = true);

  while (!cancelled) {
    try {
      var receivedData = false;
      await for (final event in client.connect()) {
        receivedData = true;
        yield event;
      }
      // Clean disconnect — reset backoff only if we actually streamed data.
      if (receivedData) {
        backoff = const Duration(seconds: 1);
      }
      if (cancelled) break;
      await Future.delayed(backoff);
      if (cancelled) break;
      backoff = backoff * 2;
      if (backoff > maxBackoff) backoff = maxBackoff;
    } catch (e) {
      if (cancelled) break;
      debugPrint('SSE error: $e. Reconnecting in ${backoff.inSeconds}s...');
      await Future.delayed(backoff);
      if (cancelled) break;
      backoff = backoff * 2;
      if (backoff > maxBackoff) backoff = maxBackoff;
    }
  }
});

final eventsListenerProvider = Provider.autoDispose<void>((ref) {
  // Watch userId so the listener is rebuilt on identity changes, ensuring
  // the old stream subscription is cleaned up before a new one is created.
  ref.watch(currentUserIdProvider);

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
      invalidateAllFamilyInstances(ref.container,tasksProvider);
      invalidateAllFamilyInstances(ref.container,calendarTasksProvider);
    case 'folder.created':
    case 'folder.updated':
    case 'folder.deleted':
      ref.invalidate(foldersProvider);
      invalidateAllFamilyInstances(ref.container,tasksProvider);
      invalidateAllFamilyInstances(ref.container,calendarTasksProvider);
    case 'tasks.batch_updated':
      invalidateAllFamilyInstances(ref.container,tasksProvider);
      invalidateAllFamilyInstances(ref.container,calendarTasksProvider);

    // ---- Memories ----
    case 'memory.created':
    case 'memory.updated':
    case 'memory.deleted':
      ref.invalidate(memoriesProvider);

    // ---- RSS ----
    case 'article.created':
    case 'article.updated':
    case 'articles.batch_updated':
      invalidateAllFamilyInstances(ref.container,articlesProvider);
      ref.invalidate(unreadCountProvider);
    case 'feed.created':
    case 'feed.updated':
      ref.invalidate(feedsProvider);
      invalidateAllFamilyInstances(ref.container,articlesProvider);
    case 'feed.deleted':
      ref.invalidate(feedsProvider);
      invalidateAllFamilyInstances(ref.container,articlesProvider);
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

    // ---- Finances ----
    case 'finances.uncategorized':
      ref.read(uncategorizedProvider.notifier).refresh();

    // ---- Calendar ----
    case 'calendar.event.created':
    case 'calendar.event.updated':
    case 'calendar.event.deleted':
      invalidateAllFamilyInstances(ref.container,eventsProvider);
    case 'calendar.calendar.created':
    case 'calendar.calendar.updated':
    case 'calendar.calendar.deleted':
      ref.invalidate(calendarsProvider);
      invalidateAllFamilyInstances(ref.container,eventsProvider);

    // ---- Coding ----
    case 'coding.project.created':
    case 'coding.project.updated':
    case 'coding.project.deleted':
    case 'coding.project.synced':
      ref.invalidate(projectsProvider);
      break;
    case 'coding.session.created':
    case 'coding.session.updated':
    case 'coding.session.deleted':
      invalidateAllFamilyInstances(ref.container, sessionsProvider);
      break;

    case 'connected':
      debugPrint('SSE connected');
      ref.read(sseGenerationProvider.notifier).state++;

  }
}
