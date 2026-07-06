import 'dart:convert';
import 'dart:developer' as developer;

import 'bmo_rich_block.dart';

/// A segment of parsed chat-message content.
///
/// After [BmoRichParser.extract] runs, the original message text is split into
/// a list of these — plain [TextSegment]s for normal markdown and
/// [RichBlockSegment]s for ```bmo:rich blocks that should render as widgets.
sealed class BmoRichSegment {
  const BmoRichSegment();
}

/// A segment of plain markdown / text to be rendered by [MarkdownBody].
class TextSegment extends BmoRichSegment {
  final String text;
  const TextSegment({required this.text});

  @override
  String toString() => 'TextSegment(len=${text.length})';
}

/// A segment containing a successfully-parsed ```bmo:rich block.
class RichBlockSegment extends BmoRichSegment {
  final BmoRichBlock block;
  const RichBlockSegment({required this.block});

  @override
  String toString() => 'RichBlockSegment(type=${block.type}, id=${block.blockId})';
}

/// A segment representing an **incomplete** ```bmo:rich fence during streaming.
///
/// Emitted when the opening ```bmo:rich has arrived but the closing ``` has
/// not yet. The raw JSON body is **discarded** — never rendered as visible
/// text — and the UI should show a placeholder (spinner / cursor) until the
/// block closes and becomes a [RichBlockSegment].
class PendingRichSegment extends BmoRichSegment {
  const PendingRichSegment();

  @override
  String toString() => 'PendingRichSegment';
}

/// Result of [BmoRichParser.extract].
class BmoRichExtraction {
  final List<BmoRichSegment> segments;
  const BmoRichExtraction({required this.segments});
}

/// Extracts ```bmo:rich code-fence blocks from accumulated message text.
///
/// Designed for streaming: operates on the **full** accumulated message text
/// every rebuild. A fence whose closing ``` hasn't arrived yet simply doesn't
/// match the regex and stays as a [TextSegment]; on the next chunk, when the
/// closing fence lands, the regex matches and the block becomes a
/// [RichBlockSegment].
///
/// Robust to:
/// - Incomplete fences (missing closing ```) — raw text preserved, re-parsed
///   next rebuild.
/// - Malformed JSON inside a complete fence — logged and kept as [TextSegment]
///   (no crash, no data loss).
class BmoRichParser {
  BmoRichParser._();

  /// Matches a complete ```bmo:rich … ``` fence.
  ///
  /// Group 1 captures the JSON body between the opening and closing fences.
  /// `dotAll: true` so `.` matches newlines.
  /// `.+?` is non-greedy so the *first* closing ``` ends the match.
  static final RegExp _fenceRegex = RegExp(
    r'```bmo:rich\s*\n'
    r'(.+?)'
    r'\n```',
    dotAll: true,
  );

  /// Matches an **opening** ```bmo:rich fence (no closing ``` required).
  ///
  /// Used to detect incomplete blocks during streaming so the raw JSON body
  /// can be hidden behind a placeholder instead of flickering as visible text.
  static final RegExp _openFenceRegex = RegExp(
    r'```bmo:rich\s*\n',
  );

  /// Extracts rich blocks from [text] and returns a list of segments.
  ///
  /// Segments preserve the original order: text before a block → block →
  /// text between blocks → block → trailing text.
  ///
  /// When [text] contains no ```bmo:rich fences, returns a single
  /// [TextSegment] wrapping the entire string so callers can take a fast path.
  static BmoRichExtraction extract(String text) {
    if (text.isEmpty) {
      return const BmoRichExtraction(segments: [TextSegment(text: '')]);
    }

    final segments = <BmoRichSegment>[];
    int lastEnd = 0;

    for (final match in _fenceRegex.allMatches(text)) {
      // Plain text before this match
      if (match.start > lastEnd) {
        segments.add(TextSegment(text: text.substring(lastEnd, match.start)));
      }

      final jsonStr = match.group(1);
      if (jsonStr == null) {
        // Should never happen — regex guarantees group 1 exists
        segments.add(TextSegment(text: match.group(0)!));
        lastEnd = match.end;
        continue;
      }

      try {
        final decoded = jsonDecode(jsonStr.trim());
        if (decoded is Map<String, dynamic>) {
          final block = BmoRichBlock.fromJson(decoded);
          segments.add(RichBlockSegment(block: block));
        } else {
          developer.log(
            'BmoRichParser: block JSON is not an object, keeping as text',
            name: 'bmo_rich',
            level: 900,
          );
          segments.add(TextSegment(text: match.group(0)!));
        }
      } catch (e) {
        developer.log(
          'BmoRichParser: invalid JSON in bmo:rich block — keeping raw text '
          '(error: $e)',
          name: 'bmo_rich',
          level: 900,
        );
        segments.add(TextSegment(text: match.group(0)!));
      }

      lastEnd = match.end;
    }

    // Trailing text after the last match.
    // If it contains an open ```bmo:rich fence without a closing ```,
    // hide the raw JSON behind a PendingRichSegment placeholder to
    // prevent flicker during streaming.
    if (lastEnd < text.length) {
      final trailing = text.substring(lastEnd);
      final openMatch = _openFenceRegex.firstMatch(trailing);

      if (openMatch != null) {
        // Text before the open fence (if any)
        if (openMatch.start > 0) {
          segments.add(
            TextSegment(text: trailing.substring(0, openMatch.start)),
          );
        }
        // Placeholder — raw JSON from here on is discarded
        segments.add(const PendingRichSegment());
      } else {
        segments.add(TextSegment(text: trailing));
      }
    }

    // If no matches at all, wrap the whole string as text
    if (segments.isEmpty) {
      return BmoRichExtraction(segments: [TextSegment(text: text)]);
    }

    return BmoRichExtraction(segments: segments);
  }
}
