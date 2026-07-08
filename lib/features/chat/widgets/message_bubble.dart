import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/bmo_rich_parser.dart';
import '../data/bmo_rich_registry.dart';
import '../data/chat_message.dart';
import 'chat_avatar.dart';
import 'reasoning_box.dart';
import 'speech_bubble.dart';

const _kMobileBreakpoint = 600.0;

/// Remove o prefixo de contexto "[contexto: ...]\n\n" de mensagens de
/// usuário para exibição. O texto original armazenado/enviado nunca é
/// alterado — a filtragem ocorre apenas na renderização.
String _displayText(ChatMessage message) {
  if (message.role != ChatRole.user) return message.text;
  final text = message.text;
  if (text.startsWith('[contexto:') && text.contains('\n\n')) {
    final endIndex = text.indexOf('\n\n');
    return text.substring(endIndex + 2);
  }
  return text;
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _kMobileBreakpoint;
    final isUser = message.role == ChatRole.user;

    final avatarSize = isMobile ? 30.0 : 36.0;
    final maxWidthFactor = isUser ? 0.65 : 0.75;

    final bubbleColor =
        isUser ? BmoColors.bodyGreen : BmoColors.screenBgElevated;
    final borderColor = isUser
        ? Color.lerp(BmoColors.bodyGreen, Colors.white, 0.18)!
        : BmoColors.textMuted.withValues(alpha: 0.35);

    final avatar = ChatAvatar(role: message.role, size: avatarSize);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubble = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * maxWidthFactor,
            ),
            child: SpeechBubble(
              color: bubbleColor,
              borderColor: borderColor,
              tailOnLeft: !isUser,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _buildContent(theme, isUser),
              ),
            ),
          );

          return Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: isUser
                ? [bubble, const SizedBox(width: 8), avatar]
                : [avatar, const SizedBox(width: 8), bubble],
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(ThemeData theme, bool isUser) {
    final children = <Widget>[];

    if (!isUser &&
        message.reasoning != null &&
        message.reasoning!.isNotEmpty) {
      children.add(ReasoningBox(
        reasoningText: message.reasoning!,
        isStreaming: message.status == ChatMessageStatus.streaming &&
            message.text.isEmpty,
      ));
    }

    children.addAll(_buildBody(theme, isUser));

    if (message.status == ChatMessageStatus.cancelled) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '(cancelado)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: BmoColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ));
    } else if (message.status == ChatMessageStatus.error) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '(erro)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.redAccent,
          ),
        ),
      ));
    }

    return children;
  }

  List<Widget> _buildBody(ThemeData theme, bool isUser) {
    if (isUser) {
      return [
        SelectableText(
          _displayText(message),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF0F1115),
          ),
        ),
      ];
    }

    // Parse rich content blocks from the accumulated message text.
    // Re-parses on every rebuild — cheap for typical chat message lengths.
    final extraction = BmoRichParser.extract(message.text);

    // Fast path: no rich blocks — use a single MarkdownBody wrapping the
    // full message text (identical behaviour to the pre-rich-content era).
    if (extraction.segments.length == 1 &&
        extraction.segments.first is TextSegment) {
      return [
        MarkdownBody(
          data: message.text,
          selectable: true,
          styleSheet: _buildMarkdownStyle(theme),
        ),
      ];
    }

    // Build interleaved widgets: MarkdownBody for text, registered widget
    // for each rich block, placeholder for incomplete blocks during streaming.
    return extraction.segments.map((segment) {
      return switch (segment) {
        TextSegment(:final text) => MarkdownBody(
            data: text,
            selectable: true,
            styleSheet: _buildMarkdownStyle(theme),
          ),
        RichBlockSegment(:final block) => BmoRichRegistry.build(block),
        PendingRichSegment() => _buildPendingPlaceholder(theme),
      };
    }).toList();
  }

  /// Placeholder shown while a ```bmo:rich block is still being streamed
  /// (opening fence arrived, closing fence not yet).
  ///
  /// Renders a small spinner in a subtle card — the raw JSON body is never
  /// shown to the user.
  Widget _buildPendingPlaceholder(ThemeData theme) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BmoColors.accentGreen,
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyle(ThemeData theme) {
    final base = theme.textTheme.bodyMedium?.copyWith(
      color: BmoColors.textPrimary,
    );
    final code = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      color: BmoColors.textPrimary,
    );

    return MarkdownStyleSheet(
      p: base,
      h1: theme.textTheme.bodyLarge?.copyWith(
        color: BmoColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      h2: theme.textTheme.bodyLarge?.copyWith(
        color: BmoColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
      h3: theme.textTheme.bodyLarge?.copyWith(
        color: BmoColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      strong: base?.copyWith(fontWeight: FontWeight.bold),
      em: base?.copyWith(fontStyle: FontStyle.italic),
      a: base?.copyWith(color: BmoColors.accentGreen),
      code: code,
      codeblockDecoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquote: base?.copyWith(color: BmoColors.textSecondary),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: BmoColors.textMuted, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 10),
      listBullet: base,
    );
  }
}
