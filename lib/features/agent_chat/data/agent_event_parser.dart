import 'dart:developer' as developer;

import 'agent_event.dart';

/// Converte um objeto JSON do SSE em [AgentEvent].
///
/// Tipo desconhecido vira [UnknownAgentEvent] (logado, ignorado pelo
/// notifier). Evento malformado — campo obrigatório faltando ou com tipo
/// errado — também vira [UnknownAgentEvent]: um evento estranho nunca derruba
/// o turno.
AgentEvent parseAgentEvent(Map<String, dynamic> json) {
  final type = json['type'];
  final sessionId = _string(json['session_id']);
  final turnId = _string(json['turn_id']);
  final seq = _int(json['seq']);

  AgentEvent unknown([String? why]) {
    developer.log(
      'evento v2 desconhecido$why: $json',
      name: 'agent_event_parser',
      level: 900,
    );
    return UnknownAgentEvent(
      type: type is String ? type : '<sem type>',
      raw: json,
      sessionId: sessionId,
      turnId: turnId,
      seq: seq,
    );
  }

  if (type is! String) return unknown();

  switch (type) {
    case 'turn.start':
      return TurnStarted(
        input: _string(json['input']) ?? 'message',
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'text.delta':
      final text = _string(json['text']);
      if (text == null) return unknown();
      return TextDelta(text, sessionId: sessionId, turnId: turnId, seq: seq);
    case 'reasoning.delta':
      final text = _string(json['text']);
      if (text == null) return unknown();
      return ReasoningDelta(text, sessionId: sessionId, turnId: turnId, seq: seq);
    case 'tool.start':
      final callId = _string(json['call_id']);
      final name = _string(json['name']);
      if (callId == null || name == null) return unknown();
      return ToolStarted(
        callId: callId,
        name: name,
        label: _string(json['label']) ?? name,
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'tool.end':
      final callId = _string(json['call_id']);
      final ok = json['ok'];
      if (callId == null || ok is! bool) return unknown();
      return ToolEnded(
        callId: callId,
        ok: ok,
        label: _string(json['label']) ?? '',
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'rich.block':
      final blockId = _string(json['block_id']);
      final richType = _string(json['rich_type']);
      final payload = json['payload'];
      if (blockId == null || richType == null || payload is! Map) {
        return unknown();
      }
      return RichBlockReceived(
        blockId: blockId,
        richType: richType,
        payload: Map<String, dynamic>.from(payload),
        mutable: json['mutable'] == true,
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'approval.request':
      final callId = _string(json['call_id']);
      final tool = _string(json['tool']);
      if (callId == null || tool == null) return unknown();
      return ApprovalRequested(
        callId: callId,
        tool: tool,
        label: _string(json['label']) ?? tool,
        summary: _string(json['summary']) ?? '',
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'turn.end':
      final status = _string(json['status']);
      if (status == null) return unknown();
      final usage = json['usage'];
      return TurnEnded(
        status: status,
        usage: usage is Map
            ? AgentUsage.fromJson(Map<String, dynamic>.from(usage))
            : null,
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    case 'error':
      return AgentErrorEvent(
        _string(json['error']) ?? 'error',
        _string(json['message']) ?? '',
        sessionId: sessionId,
        turnId: turnId,
        seq: seq,
      );
    default:
      return unknown();
  }
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;
