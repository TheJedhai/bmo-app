import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:bmo_app/features/chat/data/sse_parser.dart';

import 'agent_event.dart';
import 'agent_event_parser.dart';
import 'agent_message.dart';
import 'agent_session.dart';

/// Erro devolvido pelo bmo-server no formato `{"error", "message"}`.
class AgentChatException implements Exception {
  final int statusCode;

  /// Código curto do contrato (`not_found`, `turn_in_progress`, ...).
  final String errorCode;
  final String message;

  const AgentChatException(this.statusCode, this.errorCode, this.message);

  @override
  String toString() => 'AgentChatException($statusCode $errorCode): $message';
}

/// Decisão de aprovação enviada em `approvals`.
class AgentApprovalInput {
  final bool approved;
  final String? note;

  const AgentApprovalInput({required this.approved, this.note});

  Map<String, dynamic> toJson() => {
        'approved': approved,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

/// Cliente do `/api/v2` (contrato em `bmo-server/docs/chat-v2.md`).
///
/// Recebe um [http.Client] já embrulhado pelo `BmoHttpClient` — é ele que
/// injeta o `X-User-Id` em cada request, inclusive no streaming.
class AgentChatClient {
  final http.Client _client;
  final String _baseUrl;

  AgentChatClient({required http.Client client, required String baseUrl})
      : _client = client,
        _baseUrl = baseUrl;

  // ── turno ─────────────────────────────────────────────────────────────────

  /// `POST /api/v2/chat` em SSE. Manda `message` **ou** `approvals`.
  ///
  /// Lança [AgentChatException] antes de emitir quando o servidor responde
  /// não-200 (404 de sessão, 409 de turno em andamento, 503 do agente).
  /// `message` com aprovação pendente não erra: o servidor nega as pendências
  /// e segue o turno.
  Stream<AgentEvent> sendTurn({
    String? sessionId,
    String? message,
    Map<String, AgentApprovalInput>? approvals,
    String channel = 'app',
    int? projectId,
  }) async* {
    final body = <String, dynamic>{
      'session_id': ?sessionId,
      'message': ?message,
      if (approvals != null)
        'approvals': {
          for (final entry in approvals.entries) entry.key: entry.value.toJson(),
        },
      'channel': channel,
      // O servidor só usa `project_id` quando a sessão ainda vai nascer
      // (`session_id: null`).
      if (sessionId == null) 'project_id': ?projectId,
    };

    final request = http.Request('POST', Uri.parse('$_baseUrl/api/v2/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(body);

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      throw _exception(response.statusCode, raw);
    }

    await for (final json in parseSseStream(response.stream)) {
      yield parseAgentEvent(json);
    }
  }

  /// `POST /api/v2/sessions/{id}/cancel` (204, idempotente).
  Future<void> cancel(String sessionId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v2/sessions/$sessionId/cancel'),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw _exception(response.statusCode, response.body);
    }
  }

  // ── sessões ───────────────────────────────────────────────────────────────

  /// `GET /api/v2/sessions` (mais recentes primeiro).
  ///
  /// Sem [projectId] o servidor devolve só as sessões sem projeto (chat
  /// principal); com ele, as do projeto.
  Future<List<AgentSession>> listSessions({int? projectId}) async {
    final uri = Uri.parse('$_baseUrl/api/v2/sessions').replace(
      queryParameters: projectId == null ? null : {'project_id': '$projectId'},
    );
    final response = await _client.get(uri);
    _ensureOk(response, 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((json) => AgentSession.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// `POST /api/v2/sessions`
  Future<AgentSession> createSession({String? title, int? projectId}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v2/sessions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': ?title, 'project_id': ?projectId}),
    );
    _ensureOk(response, 201);
    return AgentSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// `PATCH /api/v2/sessions/{id}`
  Future<AgentSession> renameSession(String sessionId, String title) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/v2/sessions/$sessionId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );
    _ensureOk(response, 200);
    return AgentSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// `DELETE /api/v2/sessions/{id}`
  Future<void> deleteSession(String sessionId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/v2/sessions/$sessionId'),
    );
    if (response.statusCode != 204) {
      throw _exception(response.statusCode, response.body);
    }
  }

  /// `GET /api/v2/sessions/{id}/messages` (formato de exibição).
  Future<List<AgentMessage>> fetchMessages(String sessionId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/v2/sessions/$sessionId/messages'),
    );
    _ensureOk(response, 200);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((json) => AgentMessage.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // ── erros ─────────────────────────────────────────────────────────────────

  void _ensureOk(http.Response response, int expected) {
    if (response.statusCode != expected) {
      throw _exception(response.statusCode, response.body);
    }
  }

  AgentChatException _exception(int statusCode, String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return AgentChatException(
          statusCode,
          decoded['error']?.toString() ?? 'error',
          decoded['message']?.toString() ?? 'falha inesperada',
        );
      }
    } catch (_) {
      // Corpo não-JSON: cai no genérico abaixo.
    }
    return AgentChatException(statusCode, 'error', 'falha inesperada');
  }
}
