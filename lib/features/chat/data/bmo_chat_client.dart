import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'chat_event.dart';
import 'sse_parser.dart';

/// Cliente do bmo-server. Faz POST /api/chat (stream SSE) e CRUD em
/// /api/chats/* (gerenciamento de conversas).
class BmoChatClient {
  final http.Client _client;
  final String _baseUrl;

  BmoChatClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ============================================================
  // Streaming chat (POST /api/chat)
  // ============================================================

  Stream<ChatEvent> sendMessage({
    required String sessionId,
    required String text,
    String userId = 'bmo-app',
    String agentId = 'default',
  }) async* {
    final uri = Uri.parse('$_baseUrl/api/chat');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['X-Agent-Id'] = agentId
      ..body = jsonEncode({
        'input': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': text}
            ]
          }
        ],
        'session_id': sessionId,
        'user_id': userId,
        'channel': 'console',
      });

    http.StreamedResponse response;
    try {
      response = await _client.send(request);
    } catch (e) {
      yield StreamError(error: 'request failed: $e');
      return;
    }

    if (response.statusCode != 200) {
      yield StreamError(
        error: 'HTTP ${response.statusCode}',
        details: {'reason': response.reasonPhrase ?? ''},
      );
      return;
    }

    try {
      await for (final json in parseSseStream(response.stream)) {
        final event = ChatEvent.fromJson(json);
        if (event is UnknownEvent) {
          developer.log(
            'evento SSE não reconhecido: ${event.rawJson}',
            name: 'bmo_chat_client',
            level: 900,
          );
        }
        yield event;
      }
    } catch (e) {
      yield StreamError(error: 'stream failed: $e');
    }
  }

  // ============================================================
  // Conversas (CRUD em /api/chats)
  // ============================================================

  /// Lista todas as conversas. Retorna a lista crua de Maps.
  Future<List<Map<String, dynamic>>> listChats({
    String agentId = 'default',
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/chats'),
      headers: {'X-Agent-Id': agentId},
    );
    _ensureOk(response, 'listChats');
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) {
        return items.cast<Map<String, dynamic>>();
      }
    }
    throw StateError(
      'listChats: formato de resposta inesperado: ${response.body}',
    );
  }

  /// Busca uma conversa pelo uuid. Retorna o Map cru (inclui histórico).
  Future<Map<String, dynamic>> getChat(
    String uuid, {
    String agentId = 'default',
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/chats/$uuid'),
      headers: {'X-Agent-Id': agentId},
    );
    _ensureOk(response, 'getChat');
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw StateError('getChat: resposta não é objeto: ${response.body}');
  }

  /// Cria nova conversa. Cliente decide o session_id.
  Future<Map<String, dynamic>> createChat({
    required String sessionId,
    required String name,
    String userId = 'bmo-app',
    String channel = 'console',
    String agentId = 'default',
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/chats'),
      headers: {
        'Content-Type': 'application/json',
        'X-Agent-Id': agentId,
      },
      body: jsonEncode({
        'session_id': sessionId,
        'name': name,
        'user_id': userId,
        'channel': channel,
      }),
    );
    _ensureOk(response, 'createChat');
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw StateError('createChat: resposta não é objeto: ${response.body}');
  }

  /// Renomeia uma conversa.
  Future<Map<String, dynamic>> renameChat(
    String uuid,
    String name, {
    String agentId = 'default',
  }) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/api/chats/$uuid'),
      headers: {
        'Content-Type': 'application/json',
        'X-Agent-Id': agentId,
      },
      body: jsonEncode({'name': name}),
    );
    _ensureOk(response, 'renameChat');
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw StateError('renameChat: resposta não é objeto: ${response.body}');
  }

  /// Deleta uma conversa.
  Future<void> deleteChat(
    String uuid, {
    String agentId = 'default',
  }) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/chats/$uuid'),
      headers: {'X-Agent-Id': agentId},
    );
    _ensureOk(response, 'deleteChat');
  }

  /// Pede um título sugerido pelo LLM com base na primeira troca.
  /// Retorna null em qualquer falha (timeout, status != 200, parse, vazio).
  Future<String?> suggestTitle({
    required String userMessage,
    required String assistantMessage,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/title-suggest'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_message': userMessage,
              'assistant_message': assistantMessage,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        developer.log(
          'suggestTitle HTTP ${response.statusCode}: ${response.body}',
          name: 'bmo_chat_client',
          level: 900,
        );
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
          'suggestTitle: resposta não é objeto: ${response.body}',
          name: 'bmo_chat_client',
          level: 900,
        );
        return null;
      }
      final title = decoded['title'];
      if (title is! String || title.trim().isEmpty) {
        developer.log(
          'suggestTitle: title ausente ou vazio: ${response.body}',
          name: 'bmo_chat_client',
          level: 900,
        );
        return null;
      }
      return title.trim();
    } catch (e) {
      developer.log(
        'suggestTitle falhou: $e',
        name: 'bmo_chat_client',
        level: 900,
      );
      return null;
    }
  }

  void _ensureOk(http.Response response, String op) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw HttpException(
      '$op falhou com HTTP ${response.statusCode}: ${response.body}',
    );
  }
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
