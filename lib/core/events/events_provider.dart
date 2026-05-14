import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/missions/data/missions_providers.dart';
import '../config/env.dart';
import '../http/client_factory.dart';
import 'events_client.dart';

final eventsClientProvider = Provider<EventsClient>((ref) {
  return EventsClient(
    client: createHttpClient(),
    baseUrl: Env.bmoServerUrl,
  );
});

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
    case 'task.created':
    case 'task.updated':
    case 'task.deleted':
    case 'task.completed':
      ref.invalidate(tasksProvider);
    case 'folder.created':
    case 'folder.updated':
    case 'folder.deleted':
      ref.invalidate(foldersProvider);
      ref.invalidate(tasksProvider);
    case 'tasks.batch_updated':
      ref.invalidate(tasksProvider);
    case 'connected':
      debugPrint('SSE connected');
  }
}
