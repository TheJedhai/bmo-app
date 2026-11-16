// Campo `speech` do envelope de bloco rico: guardado no modelo e nunca
// renderizado. Ausência = null.
//
// Run:
//   flutter test test/rich_blocks/rich_block_speech_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:bmo_app/features/agent_chat/data/agent_event.dart';
import 'package:bmo_app/features/agent_chat/data/agent_event_parser.dart';
import 'package:bmo_app/features/agent_chat/data/agent_message.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';

const _envelope = {
  'v': 1,
  'type': 'memory_saved',
  'block_id': 'memory-5',
  'payload': {'memory_id': 5, 'content': 'gosta de café', 'scope': 'personal'},
  'mutable': true,
};

void main() {
  test('BmoRichBlock guarda speech quando presente', () {
    final block = BmoRichBlock.fromJson({
      ..._envelope,
      'speech': 'salvei que você gosta de café',
    });
    expect(block.speech, 'salvei que você gosta de café');
  });

  test('BmoRichBlock sem speech vira null', () {
    expect(BmoRichBlock.fromJson(_envelope).speech, isNull);
    expect(
      BmoRichBlock.fromJson({..._envelope, 'speech': 42}).speech,
      isNull,
    );
  });

  test('parte do histórico carrega speech', () {
    final part = parseAgentPart({
      'type': 'rich',
      'block_id': 'memory-5',
      'rich_type': 'memory_saved',
      'payload': _envelope['payload'],
      'mutable': true,
      'speech': 'resumo falável',
    });
    expect(part, isA<AgentRichPart>());
    expect((part! as AgentRichPart).speech, 'resumo falável');

    final withoutSpeech = parseAgentPart({
      'type': 'rich',
      'block_id': 'memory-5',
      'rich_type': 'memory_saved',
      'payload': _envelope['payload'],
      'mutable': true,
    });
    expect((withoutSpeech! as AgentRichPart).speech, isNull);
  });

  test('evento rich.block carrega speech', () {
    final event = parseAgentEvent({
      'v': 2,
      'type': 'rich.block',
      'session_id': 's1',
      'turn_id': 't1',
      'seq': 3,
      'block_id': 'memory-5',
      'rich_type': 'memory_saved',
      'payload': _envelope['payload'],
      'mutable': true,
      'speech': 'resumo falável',
    });
    expect(event, isA<RichBlockReceived>());
    expect((event as RichBlockReceived).speech, 'resumo falável');

    final withoutSpeech = parseAgentEvent({
      'v': 2,
      'type': 'rich.block',
      'session_id': 's1',
      'turn_id': 't1',
      'seq': 4,
      'block_id': 'memory-5',
      'rich_type': 'memory_saved',
      'payload': _envelope['payload'],
      'mutable': true,
    });
    expect((withoutSpeech as RichBlockReceived).speech, isNull);
  });
}
