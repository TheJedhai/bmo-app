/// Deep links bmo://.
///
/// O path do scheme espelha 1:1 o path do go_router, sem tabela de
/// tradução: `bmo://go/missoes` → `/missoes`. Se a rota existe no router, o
/// link funciona; qualquer coisa fora disso cai na raiz — sem tela de erro,
/// sem crash.
library;

/// Rotas top-level sem parâmetro. Espelha a lista de `GoRoute` em
/// `app_router.dart` — quando uma rota nova entrar lá, entra aqui também.
const _topRoutes = <String>{
  '/',
  '/chat',
  '/missoes',
  '/casa',
  '/noticias',
  '/cofre',
  '/calendario',
  '/calendarios',
  '/financas',
  '/coding',
};

/// `/coding/:projectId[/:sessionId]`. O `projectId` é lido com `int.parse`
/// no pageBuilder e estouraria num valor não numérico, então só dígitos;
/// o `sessionId` é String livre.
final _codingRoute = RegExp(r'^/coding/\d+(/.+)?$');

/// Se [path] é uma rota que o go_router conhece.
bool isKnownRoute(String path) =>
    _topRoutes.contains(path) || _codingRoute.hasMatch(path);

/// Resolve um deep link bmo:// para o path de destino.
///
/// Retorna:
/// * `null` — não é deep link nosso (scheme ≠ `bmo`, ex. o https inicial da
///   web). Ignorar, sem navegar.
/// * `'/'` — é bmo:// mas fora do formato conhecido (host ≠ `go`, path que o
///   router não conhece). Vai para a raiz.
/// * o path da rota — link válido, navega.
String? resolveDeepLinkPath(Uri uri) {
  if (uri.scheme != 'bmo') return null;
  if (uri.host != 'go') return '/';
  final path = uri.path;
  if (path.isEmpty) return '/';
  return isKnownRoute(path) ? path : '/';
}

/// Handler único de deep links.
///
/// Os dois pontos de entrada — toque num widget e notificação do ntfy —
/// desembocam aqui: ambos abrem o app com uma URL `bmo://` e chegam pelo
/// mesmo `uriLinkStream`.
class DeepLinkController {
  DeepLinkController({required this.go});

  /// Navegação de destino (normalmente `appRouter.go`).
  final void Function(String path) go;

  String? _lastUri;
  String? _pending;
  bool _ready = false;

  /// Alimenta um URI do stream.
  ///
  /// Deduplica pelo último URI tratado — o stream já entrega o link inicial
  /// do cold start; sem isso ele dispara duas vezes. Se a identidade ainda
  /// não resolveu, segura o path e só navega quando [setReady] for chamado.
  void onUri(Uri uri) {
    final key = uri.toString();
    if (key == _lastUri) return;
    _lastUri = key;

    final target = resolveDeepLinkPath(uri);
    if (target == null) return; // não é link nosso — ignora.

    if (_ready) {
      go(target);
    } else {
      _pending = target;
    }
  }

  /// Marca a identidade como resolvida e consome o link pendente, se houver.
  ///
  /// Resetar o app (troca de perfil) re-resolve a identidade; se chegou um
  /// link durante o reset, este é o momento de navegar.
  void setReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) go(pending);
  }

  /// Há um link segurado aguardando a identidade resolver?
  bool get hasPending => _pending != null;

  /// A identidade já resolveu e links chegam direto?
  bool get isReady => _ready;
}
