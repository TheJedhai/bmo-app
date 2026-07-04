import 'package:flutter_test/flutter_test.dart';
import 'package:bmo_app/features/chat/data/bmo_rich_block.dart';
import 'package:bmo_app/features/chat/data/bmo_rich_parser.dart';

void main() {
  group('BmoRichParser', () {
    // -----------------------------------------------------------------------
    // No rich blocks
    // -----------------------------------------------------------------------
    test('returns single TextSegment when text has no rich blocks', () {
      final result = BmoRichParser.extract('Hello world');
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      expect(
        (result.segments.first as TextSegment).text,
        'Hello world',
      );
    });

    test('returns single TextSegment for empty string', () {
      final result = BmoRichParser.extract('');
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      expect((result.segments.first as TextSegment).text, '');
    });

    // -----------------------------------------------------------------------
    // Single complete block
    // -----------------------------------------------------------------------
    test('extracts a single complete bmo:rich block', () {
      const text = 'Antes do bloco\n'
          '```bmo:rich\n'
          '{"v":1,"type":"image","block_id":"img-1","payload":{"image_id":42},"mutable":true}\n'
          '```\n'
          'Depois do bloco';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 3);

      // Text before
      expect(result.segments[0], isA<TextSegment>());
      expect(
        (result.segments[0] as TextSegment).text,
        'Antes do bloco\n',
      );

      // Rich block
      expect(result.segments[1], isA<RichBlockSegment>());
      final block = (result.segments[1] as RichBlockSegment).block;
      expect(block.type, 'image');
      expect(block.v, 1);
      expect(block.blockId, 'img-1');
      expect(block.payload['image_id'], 42);
      expect(block.mutable, true);

      // Text after
      expect(result.segments[2], isA<TextSegment>());
      expect(
        (result.segments[2] as TextSegment).text,
        '\nDepois do bloco',
      );
    });

    test('extracts block-only text (no surrounding content)', () {
      const text = '```bmo:rich\n'
          '{"v":1,"type":"image","block_id":"x","payload":{},"mutable":false}\n'
          '```';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<RichBlockSegment>());
    });

    // -----------------------------------------------------------------------
    // Multiple blocks
    // -----------------------------------------------------------------------
    test('extracts multiple bmo:rich blocks preserving order', () {
      const text = 'A\n'
          '```bmo:rich\n'
          '{"v":1,"type":"image","block_id":"first","payload":{},"mutable":false}\n'
          '```\n'
          'B\n'
          '```bmo:rich\n'
          '{"v":1,"type":"image","block_id":"second","payload":{},"mutable":false}\n'
          '```\n'
          'C';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 5);

      expect(result.segments[0], isA<TextSegment>());
      expect((result.segments[0] as TextSegment).text, 'A\n');

      expect(result.segments[1], isA<RichBlockSegment>());
      expect((result.segments[1] as RichBlockSegment).block.blockId, 'first');

      expect(result.segments[2], isA<TextSegment>());
      expect((result.segments[2] as TextSegment).text, '\nB\n');

      expect(result.segments[3], isA<RichBlockSegment>());
      expect((result.segments[3] as RichBlockSegment).block.blockId, 'second');

      expect(result.segments[4], isA<TextSegment>());
      expect((result.segments[4] as TextSegment).text, '\nC');
    });

    test('handles consecutive rich blocks with no text between them', () {
      const text = '```bmo:rich\n'
          '{"v":1,"type":"a","block_id":"1","payload":{},"mutable":false}\n'
          '```\n'
          '```bmo:rich\n'
          '{"v":1,"type":"b","block_id":"2","payload":{},"mutable":false}\n'
          '```';

      final result = BmoRichParser.extract(text);
      // Two consecutive blocks -> [RichBlock, Text("\n"), RichBlock]
      // The newline between them is captured as text
      expect(
        result.segments.whereType<RichBlockSegment>().length,
        2,
      );
    });

    // -----------------------------------------------------------------------
    // Incomplete fence (streaming)
    // -----------------------------------------------------------------------
    test('keeps incomplete fence as text (no closing ```)', () {
      const text = 'Hello\n```bmo:rich\n{"v":1,"type":"image"';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      expect(
        (result.segments.first as TextSegment).text,
        'Hello\n```bmo:rich\n{"v":1,"type":"image"',
      );
    });

    test('keeps text when opening fence present but no closing fence', () {
      const text = '```bmo:rich\n{"v":1}\nfaltando fechamento';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      expect((result.segments.first as TextSegment).text, text);
    });

    // -----------------------------------------------------------------------
    // Malformed JSON
    // -----------------------------------------------------------------------
    test('treats malformed JSON inside complete fence as TextSegment', () {
      const text = '```bmo:rich\n{isto nao é json valido}\n```';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      // The raw fence text is preserved
      expect(
        (result.segments.first as TextSegment).text,
        contains('```bmo:rich'),
      );
    });

    test('treats non-object JSON (e.g. array) as TextSegment', () {
      const text = '```bmo:rich\n[1, 2, 3]\n```';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
    });

    // -----------------------------------------------------------------------
    // Lenient parsing — missing fields
    // -----------------------------------------------------------------------
    test('BmoRichBlock.fromJson fills defaults for missing fields', () {
      final block = BmoRichBlock.fromJson(const {});
      expect(block.v, 1);
      expect(block.type, '');
      expect(block.blockId, '');
      expect(block.payload, const {});
      expect(block.mutable, false);
    });

    test('BmoRichBlock.fromJson handles wrong types gracefully', () {
      final block = BmoRichBlock.fromJson(const {
        'v': 'not_a_number',
        'type': null,
        'block_id': 123,
        'payload': 'not_a_map',
        'mutable': 1,
      });
      // Should not throw — BmoRichBlock.fromJson is lenient
      expect(block.v, 1); // falls back to default
      expect(block.type, '');
      expect(block.blockId, '');
      expect(block.payload, const {}); // not a map
      expect(block.mutable, false); // 1 is not bool in Dart
    });

    // -----------------------------------------------------------------------
    // Normal code fences are NOT matched
    // -----------------------------------------------------------------------
    test('ignores normal code fences (not bmo:rich)', () {
      const text = '```dart\nprint("oi");\n```';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
      expect((result.segments.first as TextSegment).text, text);
    });

    test('ignores bmo:rich without proper fence syntax', () {
      const text = 'Some `bmo:rich` inline code';

      final result = BmoRichParser.extract(text);
      expect(result.segments.length, 1);
      expect(result.segments.first, isA<TextSegment>());
    });
  });
}
