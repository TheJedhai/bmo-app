// Modelo + cliente de memórias: aliases camelCase/snake_case, escopo
// (`personal`) no create/update, `scope` na listagem e busca com score.
//
// Run:
//   flutter test test/memories/memory_model_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bmo_app/features/memories/data/memories_client.dart';
import 'package:bmo_app/features/memories/data/memory_model.dart';

Map<String, dynamic> _json({
  int? userId,
  String? createdAt,
  String? updatedAt,
}) =>
    {
      'id': 7,
      'content': 'gosta de café',
      'source': 'manual',
      'userId': userId,
      'createdAt': createdAt ?? '2026-11-01T10:00:00Z',
      'updatedAt': updatedAt ?? '2026-11-02T10:00:00Z',
    };

void main() {
  group('Memory.fromJson', () {
    test('lê aliases camelCase e escopo pessoal', () {
      final m = Memory.fromJson(_json(userId: 2));
      expect(m.id, 7);
      expect(m.userId, 2);
      expect(m.isPersonal, isTrue);
      expect(MemoryScope.of(m), MemoryScope.personal);
      expect(m.createdAt.year, 2026);
      expect(m.updatedAt.month, 11);
    });

    test('userId nulo = memória da casa', () {
      final m = Memory.fromJson(_json());
      expect(m.userId, isNull);
      expect(MemoryScope.of(m), MemoryScope.house);
    });

    test('aceita snake_case quando o servidor não usa alias', () {
      final m = Memory.fromJson({
        'id': '9',
        'content': 'x',
        'source': 'agent',
        'user_id': '3',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });
      expect(m.id, 9);
      expect(m.userId, 3);
      expect(m.createdAt.year, 2026);
      expect(m.updatedAt.day, 2);
    });

    test('lê score da busca', () {
      final m = Memory.fromJson({..._json(), 'score': 0.87});
      expect(m.score, closeTo(0.87, 1e-9));
    });
  });

  group('MemoriesClient', () {
    test('list manda scope=personal', () async {
      late Uri captured;
      final client = MemoriesClient(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode([_json(userId: 2)]), 200);
        }),
        baseUrl: 'http://fake',
      );

      final list = await client.list(scope: MemoryScope.personal);

      expect(captured.path, '/api/v1/memories');
      expect(captured.queryParameters['scope'], 'personal');
      expect(list.single.isPersonal, isTrue);
    });

    test('search manda q e scope', () async {
      late Uri captured;
      final client = MemoriesClient(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode([]), 200);
        }),
        baseUrl: 'http://fake',
      );

      await client.search(query: 'café', scope: MemoryScope.house);

      expect(captured.path, '/api/v1/memories/search');
      expect(captured.queryParameters['q'], 'café');
      expect(captured.queryParameters['scope'], 'house');
    });

    test('create manda personal:true', () async {
      late Map<String, dynamic> body;
      final client = MemoriesClient(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_json(userId: 2)), 201);
        }),
        baseUrl: 'http://fake',
      );

      final created = await client.create('nova', personal: true);

      expect(body['content'], 'nova');
      expect(body['personal'], isTrue);
      expect(created.isPersonal, isTrue);
    });

    test('update manda só os campos informados', () async {
      late Map<String, dynamic> body;
      final client = MemoriesClient(
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_json()), 200);
        }),
        baseUrl: 'http://fake',
      );

      await client.update(7, personal: false);

      expect(body, {'personal': false});
    });

    test('get devolve 404 como MemoriesApiException', () async {
      final client = MemoriesClient(
        client: MockClient((request) async => http.Response(
              jsonEncode({'error': 'memory_not_found', 'message': 'x'}),
              404,
            )),
        baseUrl: 'http://fake',
      );

      await expectLater(
        client.get(7),
        throwsA(isA<MemoriesApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });
}
