import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../../core/widgets/bmo_frame.dart';
import '../data/agent_message.dart';
import 'agent_part_widgets.dart';
import 'chat_avatar.dart';
import 'speech_bubble.dart';

class AgentMessageBubble extends StatelessWidget {
  final AgentMessage message;
  final bool streaming;
  final void Function(String callId) onApprove;
  final void Function(String callId, String? note) onDeny;

  const AgentMessageBubble({
    super.key,
    required this.message,
    required this.onApprove,
    required this.onDeny,
    this.streaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.role == AgentRole.system) {
      return _SystemMessage(message: message);
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < kMobileBreakpoint;
    final isUser = message.role == AgentRole.user;

    final avatarSize = isMobile ? 30.0 : 36.0;
    final bubbleColor =
        isUser ? BmoColors.bodyGreen : BmoColors.screenBgElevated;
    final borderColor = isUser
        ? Color.lerp(BmoColors.bodyGreen, Colors.white, 0.18)!
        : BmoColors.textMuted.withValues(alpha: 0.35);

    final avatar = ChatAvatar(
      role: isUser ? AgentRole.user : AgentRole.assistant,
      size: avatarSize,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bubble = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * (isUser ? 0.65 : 0.75),
            ),
            child: SpeechBubble(
              color: bubbleColor,
              borderColor: borderColor,
              tailOnLeft: !isUser,
              child: isUser
                  ? SelectableText(
                      message.plainText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF0F1115),
                          ),
                    )
                  : _AssistantParts(
                      message: message,
                      streaming: streaming,
                      onApprove: onApprove,
                      onDeny: onDeny,
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
}

/// Mensagem do servidor (`role: "system"`): linhas de evento, sem bolha.
class _SystemMessage extends StatelessWidget {
  final AgentMessage message;

  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final part in message.parts)
            switch (part) {
              AgentEventPart() => AgentEventLine(part: part),
              AgentTextPart() => AgentEventLine(
                  part: AgentEventPart(text: part.text),
                ),
              _ => const SizedBox.shrink(),
            },
        ],
      ),
    );
  }
}

/// Numa mensagem, o cartão de aprovação vem antes do bloco rico que a
/// ferramenta aprovada gerou. O servidor manda na ordem `tool → rich →
/// approval`; aqui as peças ricas ficam num buffer e são despejadas depois
/// das aprovações contíguas.
List<AgentPart> _orderCards(List<AgentPart> parts) {
  final out = <AgentPart>[];
  final pendingRich = <AgentPart>[];
  for (final part in parts) {
    if (part is AgentRichPart) {
      pendingRich.add(part);
      continue;
    }
    if (part is AgentApprovalPart) {
      out.add(part);
      continue;
    }
    out.addAll(pendingRich);
    pendingRich.clear();
    out.add(part);
  }
  out.addAll(pendingRich);
  return out;
}

class _AssistantParts extends StatelessWidget {
  final AgentMessage message;
  final bool streaming;
  final void Function(String callId) onApprove;
  final void Function(String callId, String? note) onDeny;

  const _AssistantParts({
    required this.message,
    required this.streaming,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    if (message.parts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: BmoColors.accentGreen,
          ),
        ),
      );
    }

    final parts = _orderCards(message.parts);
    final children = <Widget>[];
    for (var index = 0; index < parts.length; index++) {
      final part = parts[index];
      final isLast = index == parts.length - 1;
      switch (part) {
        case AgentTextPart():
          children.add(AgentTextBlock(text: part.text));
        case AgentEventPart():
          children.add(AgentEventLine(part: part));
        case AgentReasoningPart():
          children.add(
            AgentReasoningBlock(text: part.text, isStreaming: streaming && isLast),
          );
        case AgentToolPart():
          children.add(AgentToolChip(part: part));
        case AgentRichPart():
          children.add(AgentRichBlockView(part: part));
        case AgentApprovalPart():
          children.add(
            AgentApprovalCard(
              part: part,
              onApprove: onApprove,
              onDeny: onDeny,
            ),
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
