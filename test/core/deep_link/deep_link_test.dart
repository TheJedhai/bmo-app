import 'package:bmo_app/core/deep_link/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

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
