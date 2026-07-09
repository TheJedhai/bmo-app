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
///
/// O [UserIdGetter] lê [currentUserIdProvider] a cada [BmoHttpClient.send],
/// não no momento da construção do client. Isso garante que mesmo providers
/// que cacheiam uma referência antiga ao [BmoHttpClient] (ex.: repository
/// providers que usavam ref.read) ainda enviem o X-User-Id correto —
/// a identidade é sempre resolvida no momento do request.
final httpClientProvider = Provider<http.Client>((ref) {
  ref.watch(currentUserIdProvider); // mantém reatividade para side-effects (SSE etc)
  return BmoHttpClient(impl.createHttpClient(), () {
    final uid = ref.read(currentUserIdProvider);
    return uid?.toString() ?? '';
  });
});
