import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../identity/identity_state.dart';
import 'bmo_http_client.dart';
import 'client_factory_io.dart'
    if (dart.library.html) 'client_factory_web.dart' as impl;

/// Cria um http.Client adequado à plataforma:
/// - Web: FetchClient (Fetch API, suporta streaming SSE)
/// - IO (mobile/desktop): http.Client padrão
///
/// Se [userId] for informado, o client é envelopado em um [BmoHttpClient]
/// que adiciona o header X-User-Id automaticamente a todo request.
http.Client createHttpClient({String? userId}) {
  final base = impl.createHttpClient();
  if (userId != null && userId.isNotEmpty) {
    return BmoHttpClient(base, () => userId);
  }
  return base;
}

/// Provider único de [http.Client] para uso em notifiers que precisam de HTTP.
///
/// Reage a [currentUserIdProvider]: quando o perfil muda, o client é
/// reconstruído com o novo X-User-Id, e todos os providers dependentes
/// (clients, repositories, notifiers) rebuildam automaticamente.
final httpClientProvider = Provider<http.Client>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return createHttpClient(userId: userId?.toString());
});
