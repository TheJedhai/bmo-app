import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'chat_event.dart';
import 'sse_parser.dart';

/// Cliente do bmo-server. Faz POST /api/chat e expõe o stream SSE como
/// `Stream<ChatEvent>`.
class BmoChatClient {
  final http.Client _client;
  final String _baseUrl;

  BmoChatClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

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
}
