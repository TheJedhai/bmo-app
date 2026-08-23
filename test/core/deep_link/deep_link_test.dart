import 'package:bmo_app/core/deep_link/deep_link.dart';
import 'package:bmo_app/core/navigation/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Andar na árvore de rotas do router e coletar os full paths de [GoRoute].
///
/// Paths de rotas aninhadas são relativos (ex.: `:sessionId` sob
/// `/coding/:projectId`), então o full path compõe o parent. A shell não
/// contribui path.
List<String> _collectFullPaths(List<RouteBase> routes, String parent) {
  final out = <String>[];
  for (final route in routes) {
    if (route is ShellRoute) {
      out.addAll(_collectFullPaths(route.routes, parent));
    } else if (route is GoRoute) {
      final full =
          route.path.startsWith('/') ? route.path : '$parent/${route.path}';
      out.add(full);
      out.addAll(_collectFullPaths(route.routes, full));
    }
  }
  return out;
}

/// Substitui segmentos `:param` por um valor de exemplo válido.
String _substituteParams(String path) =>
    path.replaceAllMapped(RegExp(r':[A-Za-z_]+'), (_) => '1');

void main() {
  group('resolveDeepLinkPath', () {
    test('mapeia bmo://go/<rota> 1:1 para o path do go_router', () {
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/missoes')), '/missoes');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/casa')), '/casa');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/calendarios')), '/calendarios');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/cofre')), '/cofre');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/noticias')), '/noticias');
    });

    test('rota com parâmetro /coding/:projectId[/:sessionId] funciona', () {
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/coding/123')), '/coding/123');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/coding/123/abc')), '/coding/123/abc');
    });

    test('path desconhecido -> raiz, sem crash', () {
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/nao-existe')), '/');
      // projectId é int.parse no pageBuilder — valor não numérico cai na raiz.
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/coding/abc')), '/');
    });

    test('link da raiz (bmo://go) -> /', () {
      expect(resolveDeepLinkPath(Uri.parse('bmo://go')), '/');
      expect(resolveDeepLinkPath(Uri.parse('bmo://go/')), '/');
    });

    test('não é deep link nosso (scheme ≠ bmo) -> null (ignora)', () {
      expect(resolveDeepLinkPath(Uri.parse('https://example.com/missoes')), isNull);
      expect(resolveDeepLinkPath(Uri.parse('foo://bar')), isNull);
    });

    test('bmo:// fora do formato (host ≠ go) -> /', () {
      expect(resolveDeepLinkPath(Uri.parse('bmo://outro/x')), '/');
    });
  });

  group('cobertura contra o router', () {
    test('toda rota do go_router é deep-link-al (rede contra lista manual)', () {
      final paths = _collectFullPaths(appRouter.configuration.routes, '');
      expect(paths, isNotEmpty, reason: 'router deveria ter rotas');
      for (final raw in paths) {
        final target = _substituteParams(raw);
        final uri = Uri.parse('bmo://go$target');
        expect(
          resolveDeepLinkPath(uri),
          target,
          reason: 'rota "$raw" (como $uri) deveria resolver, não cair na raiz',
        );
      }
    });
  });

  group('DeepLinkController', () {
    test('identidade já resolvida -> navega na hora', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.setReady();
      c.onUri(Uri.parse('bmo://go/missoes'));
      expect(called, ['/missoes']);
    });

    test('deduplicação: mesmo URI não dispara duas vezes (cold start single fire)', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.setReady();
      c.onUri(Uri.parse('bmo://go/missoes'));
      c.onUri(Uri.parse('bmo://go/missoes'));
      expect(called, ['/missoes']);
    });

    test('link antes do perfil resolver -> segurado e consumido após setReady', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.onUri(Uri.parse('bmo://go/missoes'));
      expect(called, isEmpty);
      expect(c.hasPending, isTrue);
      expect(c.isReady, isFalse);
      c.setReady();
      expect(called, ['/missoes']);
      expect(c.hasPending, isFalse);
    });

    test('último link vence quando vários chegam antes de resolver', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.onUri(Uri.parse('bmo://go/missoes'));
      c.onUri(Uri.parse('bmo://go/casa'));
      c.setReady();
      expect(called, ['/casa']);
    });

    test('path desconhecido pendente -> resolvido depois para a raiz', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.onUri(Uri.parse('bmo://go/nao-existe'));
      c.setReady();
      expect(called, ['/']);
    });

    test('URI que não é deep link nosso (https) -> ignora, não navega', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.setReady();
      c.onUri(Uri.parse('https://example.com/'));
      expect(called, isEmpty);
    });

    test('setReady sem link pendente -> não navega', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.setReady();
      expect(called, isEmpty);
    });

    test('_ready é pegajoso: links quentes após resolver navegam imediatamente', () {
      final called = <String>[];
      final c = DeepLinkController(go: called.add);
      c.setReady();
      c.onUri(Uri.parse('bmo://go/cofre'));
      expect(called, ['/cofre']);
      // Um link quente diferente chega depois — já pronto, navega na hora.
      c.onUri(Uri.parse('bmo://go/financas'));
      expect(called, ['/cofre', '/financas']);
    });
  });
}
