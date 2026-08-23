import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_provider.dart';
import '../navigation/app_router.dart';
import 'deep_link.dart';

/// Ouve o `uriLinkStream` do app_links e navega para a rota correspondente.
///
/// Montado no builder do `MaterialApp` (acima do Navigator), uma vez por vida
/// do app. Na web o scheme bmo não existe e o stream emite apenas o https
/// inicial, que o handler ignora — tudo sai natural, sem gate de
/// `kIsWeb`/`Platform`.
///
/// Regras:
/// * Só `uriLinkStream`. Não usar `getInitialLink()` junto dele — o stream já
///   entrega o link inicial do cold start; os dois disparariam o link duas
///   vezes. Sobra a deduplicação por último URI tratado em [DeepLinkController].
/// * O link pode chegar antes de a identidade resolver (perfil vindo do
///   shared_preferences ou o app caindo no seletor "Quem está usando?").
///   Navegar antes disso leva a uma tela com userId null, que o guard do shell
///   renderiza vazia. Então o path é segurado como pendente e só consumido
///   quando o `currentUserProvider` resolve (AsyncData).
class DeepLinkHandler extends ConsumerStatefulWidget {
  const DeepLinkHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends ConsumerState<DeepLinkHandler> {
  // app_links é singleton; o próprio stream já entrega o link inicial do cold
  // start, então um único subscribe cobre os dois pontos de entrada.
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  late final DeepLinkController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DeepLinkController(go: (path) => appRouter.go(path));
    _sub = _appLinks.uriLinkStream.listen(_controller.onUri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Só navega o link pendente depois que a identidade resolveu. O handler
    // monta no runApp quando o currentUserProvider ainda é AsyncLoading — o
    // transition loading→AsyncData dispara o listen e chama setReady. Como só
    // ouvimos Mudanças (ref.listen de build não tem fireImmediately), não há
    // chamada duplicada de setReady no boot.
    ref.listen(
      currentUserProvider,
      (previous, next) {
        if (next is AsyncData) _controller.setReady();
      },
    );
    return widget.child;
  }
}
