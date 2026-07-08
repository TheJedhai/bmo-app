import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Valor síncrono do userId atual.
///
/// Modificado exclusivamente pelo [CurrentUser] notifier — widgets não
/// devem escrever neste provider diretamente. Usado por [BmoHttpClient]
/// para injetar o header X-User-Id.
final currentUserIdProvider = StateProvider<String?>((ref) => null);

/// Conjunto de keys de features opt-in retornadas por /api/v1/me.
///
/// Widgets de dock/modais podem declarar uma key e só renderizar se ela
/// estiver neste conjunto:
/// ```dart
/// final features = ref.watch(enabledFeaturesProvider);
/// if (!features.contains('rss')) return const SizedBox.shrink();
/// ```
final enabledFeaturesProvider = StateProvider<Set<String>>((ref) => const {});
