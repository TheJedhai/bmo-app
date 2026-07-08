import 'package:http/http.dart' as http;

/// Callback síncrono que retorna o userId atual (ou null se nenhum perfil
/// estiver selecionado). Usado pelo [BmoHttpClient] para injetar o header
/// X-User-Id sem depender do Riverpod.
typedef UserIdGetter = String? Function();

/// Wrapper decorator de [http.Client] que adiciona o header X-User-Id em
/// todo request enviado ao bmo-server.
///
/// Encapsula um [http.Client] real (plataforma-adaptativo) e injeta o
/// header automaticamente no método [send] — que é o ponto único por onde
/// passam todas as operações HTTP (REST e streaming SSE).
///
/// Quando não há perfil selecionado ([userIdGetter] retorna null ou vazio),
/// o header NÃO é adicionado, mantendo compatibilidade com requests que não
/// exigem identidade.
class BmoHttpClient extends http.BaseClient {
  final http.Client _inner;
  final UserIdGetter _userIdGetter;

  BmoHttpClient(this._inner, this._userIdGetter);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final userId = _userIdGetter();
    if (userId != null && userId.isNotEmpty) {
      request.headers['X-User-Id'] = userId;
    }
    return _inner.send(request);
  }
}
