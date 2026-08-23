/// Deep links bmo://.
///
/// O path do scheme espelha 1:1 o path do go_router, sem tabela de
/// tradução: `bmo://go/missoes` → `/missoes`. Se a rota existe no router, o
/// link funciona; qualquer coisa fora disso cai na raiz — sem tela de erro,
/// sem crash.
library;

import '../navigation/app_router.dart';

/// Consulta o go_router: esta rota existe?
///
/// A fonte única é a [RouteConfiguration] de que o [appRouter] foi construído
/// — não uma lista espelhada aqui. Adicionar uma rota no router faz o deep
/// link aceitá-la automaticamente; esquecer de registrar deixa de ser um erro
/// silencioso. `findMatch` retorna `error != null` quando não há rota para o
/// location (path desconhecido, path com trailing-slash, etc.).
bool isKnownRoute(String path) =>
    appRouter.configuration.findMatch(Uri(path: path)).error == null;

/// Guarda de crash do que o router casa mas o pageBuilder quebra.
///
/// `/coding/:projectId` é lido com `int.parse` no pageBuilder. O router casa
/// `abc` como `projectId` (parâmetro é String pro matcher), mas o `int.parse`
/// estouraria — o guard fica aqui, fora do `findMatch`, porque o router não
/// conhece o tipo do parâmetro. `sessionId` é String livre e não entra.
bool _paramCrashesPageBuilder(String path) {
  final parts = path.split('/');
  // parts = ['', 'coding', '<projectId>', ...]
  if (parts.length < 3 || parts[1] != 'coding') return false;
  return int.tryParse(parts[2]) == null;
}

/// Resolve um deep link bmo:// para o path de destino.
///
/// Retorna:
/// * `null` — não é deep link nosso (scheme ≠ `bmo`, ex. o https inicial da
///   web). Ignorar, sem navegar.
/// * `'/'` — é bmo:// mas fora do formato conhecido (host ≠ `go`, path que o
///   router não conhece ou que estouraria no pageBuilder). Vai para a raiz.
/// * o path da rota — link válido, navega.
String? resolveDeepLinkPath(Uri uri) {
  if (uri.scheme != 'bmo') return null;
  if (uri.host != 'go') return '/';
  final path = uri.path;
  if (path.isEmpty) return '/';
  if (!isKnownRoute(path)) return '/';
  // Rota conhecida, mas o valor do parâmetro quebraria o pageBuilder.
  if (_paramCrashesPageBuilder(path)) return '/';
  return path;
}

/// Handler único de deep links.
///
/// Os dois pontos de entrada — toque num widget e notificação do ntfy —
/// desembocam aqui: ambos abrem o app com uma URL `bmo://` e chegam pelo
/// mesmo `uriLinkStream`.
class DeepLinkController {
  DeepLinkController({required this.go, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// Navegação de destino (normalmente `appRouter.go`).
  final void Function(String path) go;

  /// Fonte de tempo (injetável para teste).
  final DateTime Function() _now;

  /// Janela de deduplicação. A entrega dupla do sistema — o mesmo link
  /// disparado duas vezes no boot — é sub-segundo; um toque real do usuário
  /// nunca é. 1s separa os dois: deduplica a dupla entrega sem bloquear um
  /// toque legítimo pouco depois.
  static const _dedupWindow = Duration(seconds: 1);

  String? _lastUri;
  DateTime? _lastUriAt;
  String? _pending;
  bool _ready = false;

  /// Alimenta um URI do stream.
  ///
  /// Dedup por janela de tempo, não por igualdade eterna: a entrega dupla do
  /// sistema chega em rajada (sub-segundo) e é descartada; o mesmo link tocado
  /// de novo mais tarde navega. Se a identidade ainda não resolveu, segura o
  /// path e só navega quando [setReady] for chamado.
  void onUri(Uri uri) {
    final key = uri.toString();
    final at = _now();
    final isDuplicate = key == _lastUri &&
        _lastUriAt != null &&
        at.difference(_lastUriAt!) < _dedupWindow;
    if (isDuplicate) return;
    _lastUri = key;
    _lastUriAt = at;

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
  ///
  /// Consumir o pendente zera o dedup: o link segurado chegou antes de a
  /// identidade resolver, e o instante de chegada não pode bloquear um toque
  /// legítimo no mesmo link logo depois — esse toque é ação do usuário, não a
  /// entrega dupla que o dedup existe para pegar.
  void setReady() {
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      _lastUri = null;
      _lastUriAt = null;
      go(pending);
    }
  }

  /// Há um link segurado aguardando a identidade resolver?
  bool get hasPending => _pending != null;

  /// A identidade já resolveu e links chegam direto?
  bool get isReady => _ready;
}
