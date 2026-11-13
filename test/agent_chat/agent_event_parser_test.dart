// Um caso por tipo de evento do contrato (bmo-server/docs/chat-v2.md) mais o
// tipo desconhecido e o evento malformado.
//
// Run:
//   flutter test test/agent_chat/agent_event_parser_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event_parser.dart';

AgentEvent _parse(String raw) =>
    parseAgentEvent(jsonDecode(raw) as Map<String, dynamic>);

void main() {
  const session = 'sess-1';
  const turn = 'turn-1';

  test('turn.start traz o tipo de entrada e o envelope', () {
    final event = _parse('''
      {"v": 2, "type": "turn.start", "session_id": "$session",
       "turn_id": "$turn", "seq": 0, "input": "message"}
    ''');

    expect(event, isA<TurnStarted>());
    final started = event as TurnStarted;
    expect(started.input, 'message');
    expect(started.sessionId, session);
    expect(started.turnId, turn);
    expect(started.seq, 0);
  });

  test('text.delta', () {
    final event = _parse('''
      {"v": 2, "type": "text.delta", "session_id": "$session",
       "turn_id": "$turn", "seq": 1, "text": "Olá! "}
    ''');

    expect(event, isA<TextDelta>());
    expect((event as TextDelta).text, 'Olá! ');
    expect(event.seq, 1);
  });

  test('reasoning.delta', () {
    final event = _parse('''
      {"v": 2, "type": "reasoning.delta", "session_id": "$session",
       "turn_id": "$turn", "seq": 2, "text": "pensando..."}
    ''');

    expect(event, isA<ReasoningDelta>());
    expect((event as ReasoningDelta).text, 'pensando...');
  });

  test('tool.start', () {
    final event = _parse('''
      {"v": 2, "type": "tool.start", "session_id": "$session",
       "turn_id": "$turn", "seq": 3, "call_id": "call-1",
       "name": "list_tasks", "label": "Listar tarefas"}
    ''');

    expect(event, isA<ToolStarted>());
    final tool = event as ToolStarted;
    expect(tool.callId, 'call-1');
    expect(tool.name, 'list_tasks');
    expect(tool.label, 'Listar tarefas');
  });

  test('tool.end', () {
    final event = _parse('''
      {"v": 2, "type": "tool.end", "session_id": "$session",
       "turn_id": "$turn", "seq": 4, "call_id": "call-1", "ok": false,
       "label": "Listar tarefas"}
    ''');

    expect(event, isA<ToolEnded>());
    final tool = event as ToolEnded;
    expect(tool.callId, 'call-1');
    expect(tool.ok, isFalse);
    expect(tool.label, 'Listar tarefas');
  });

  test('rich.block', () {
    final event = _parse('''
      {"v": 2, "type": "rich.block", "session_id": "$session",
       "turn_id": "$turn", "seq": 5, "block_id": "image-demo",
       "rich_type": "image", "payload": {"image_id": 1}, "mutable": true}
    ''');

    expect(event, isA<RichBlockReceived>());
    final rich = event as RichBlockReceived;
    expect(rich.blockId, 'image-demo');
    expect(rich.richType, 'image');
    expect(rich.payload, {'image_id': 1});
    expect(rich.mutable, isTrue);
  });

  test('approval.request', () {
    final event = _parse('''
      {"v": 2, "type": "approval.request", "session_id": "$session",
       "turn_id": "$turn", "seq": 6, "call_id": "call-9",
       "tool": "delete_task", "label": "Apagar tarefa",
       "summary": "Apagar a tarefa #12"}
    ''');

    expect(event, isA<ApprovalRequested>());
    final approval = event as ApprovalRequested;
    expect(approval.callId, 'call-9');
    expect(approval.tool, 'delete_task');
    expect(approval.label, 'Apagar tarefa');
    expect(approval.summary, 'Apagar a tarefa #12');
  });

  test('turn.end com usage', () {
    final event = _parse('''
      {"v": 2, "type": "turn.end", "session_id": "$session",
       "turn_id": "$turn", "seq": 7, "status": "completed",
       "usage": {"input_tokens": 1200, "output_tokens": 45,
                 "cache_hit_tokens": 900}}
    ''');

    expect(event, isA<TurnEnded>());
    final end = event as TurnEnded;
    expect(end.status, 'completed');
    expect(end.usage?.inputTokens, 1200);
    expect(end.usage?.outputTokens, 45);
    expect(end.usage?.cacheHitTokens, 900);
  });

  test('turn.end sem usage (aguardando aprovação)', () {
    final event = _parse('''
      {"v": 2, "type": "turn.end", "session_id": "$session",
       "turn_id": "$turn", "seq": 8, "status": "awaiting_approval",
       "usage": null}
    ''');

    expect((event as TurnEnded).usage, isNull);
    expect(event.status, 'awaiting_approval');
  });

  test('error', () {
    final event = _parse('''
      {"v": 2, "type": "error", "session_id": "$session",
       "turn_id": "$turn", "seq": 9, "error": "internal_error",
       "message": "Um erro inesperado ocorreu"}
    ''');

    expect(event, isA<AgentErrorEvent>());
    final error = event as AgentErrorEvent;
    expect(error.error, 'internal_error');
    expect(error.message, 'Um erro inesperado ocorreu');
  });

  test('tipo desconhecido vira UnknownAgentEvent, não lança', () {
    final event = _parse('''
      {"v": 2, "type": "rich.update", "session_id": "$session",
       "turn_id": "$turn", "seq": 10, "block_id": "x"}
    ''');

    expect(event, isA<UnknownAgentEvent>());
    final unknown = event as UnknownAgentEvent;
    expect(unknown.type, 'rich.update');
    expect(unknown.raw['block_id'], 'x');
  });

  test('evento malformado vira UnknownAgentEvent', () {
    expect(
      _parse('{"type": "text.delta", "session_id": "s"}'),
      isA<UnknownAgentEvent>(),
    );
    expect(_parse('{"session_id": "s"}'), isA<UnknownAgentEvent>());
    expect(
      _parse('{"type": "tool.end", "call_id": "c", "ok": "sim"}'),
      isA<UnknownAgentEvent>(),
    );
  });
}
