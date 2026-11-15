import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../chat/data/bmo_rich_block.dart';
import '../../chat/data/bmo_rich_registry.dart';
import '../../chat/widgets/reasoning_box.dart';
import '../data/agent_message.dart';

/// Texto do assistente em markdown, com os mesmos estilos do chat v1.
class AgentTextBlock extends StatelessWidget {
  final String text;

  const AgentTextBlock({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: buildAgentMarkdownStyle(Theme.of(context)),
    );
  }
}

MarkdownStyleSheet buildAgentMarkdownStyle(ThemeData theme) {
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
    h1: base?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
    h2: base?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
    h3: base?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
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
      border: Border(left: BorderSide(color: BmoColors.textMuted, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 10),
    listBullet: base,
  );
}

class AgentReasoningBlock extends StatelessWidget {
  final String text;
  final bool isStreaming;

  const AgentReasoningBlock({
    super.key,
    required this.text,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return ReasoningBox(reasoningText: text, isStreaming: isStreaming);
  }
}

/// Chip de ferramenta: label pt-BR vinda do servidor + estado.
class AgentToolChip extends StatelessWidget {
  final AgentToolPart part;

  const AgentToolChip({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `awaiting` é um relógio parado (sem spinner): o turno acabou, quem tem
    // que agir é o usuário. `denied` não é falha, é decisão.
    final (color, icon) = switch (part.status) {
      AgentToolStatus.running => (BmoColors.accentYellow, null),
      AgentToolStatus.awaiting => (BmoColors.accentYellow, Icons.hourglass_empty),
      AgentToolStatus.ok => (BmoColors.accentGreen, Icons.check),
      AgentToolStatus.failed => (BmoColors.accentRed, Icons.close),
      AgentToolStatus.denied => (BmoColors.textSecondary, Icons.block),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              part.label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bloco rico: usa o registry global (image e question já registrados).
class AgentRichBlockView extends StatelessWidget {
  final AgentRichPart part;

  const AgentRichBlockView({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    return BmoRichRegistry.build(
      BmoRichBlock(
        v: 2,
        type: part.richType,
        blockId: part.blockId,
        payload: part.payload,
        mutable: part.mutable,
      ),
    );
  }
}

/// Card de aprovação: summary + Aprovar/Negar (motivo opcional) e o estado
/// decidido depois do clique.
class AgentApprovalCard extends StatefulWidget {
  final AgentApprovalPart part;
  final void Function(String callId) onApprove;
  final void Function(String callId, String? note) onDeny;

  const AgentApprovalCard({
    super.key,
    required this.part,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  State<AgentApprovalCard> createState() => _AgentApprovalCardState();
}

class _AgentApprovalCardState extends State<AgentApprovalCard> {
  final _noteController = TextEditingController();
  bool _noteOpen = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = widget.part;
    final decided = part.decision != AgentApprovalDecision.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        border: Border.all(
          color: (decided ? BmoColors.textMuted : BmoColors.accentYellow)
              .withValues(alpha: 0.6),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                decided ? Icons.lock_outline : Icons.lock_open,
                size: 16,
                color: decided ? BmoColors.textMuted : BmoColors.accentYellow,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            part.summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (!decided) ...[
            if (_noteOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _noteController,
                  autofocus: true,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'motivo (opcional)',
                    hintStyle: theme.textTheme.bodySmall?.copyWith(
                      color: BmoColors.textMuted,
                    ),
                    filled: true,
                    fillColor: BmoColors.screenBgElevated,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                FilledButton(
                  onPressed: () => widget.onApprove(part.callId),
                  style: FilledButton.styleFrom(
                    backgroundColor: BmoColors.accentGreen,
                    foregroundColor: const Color(0xFF0F1115),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Aprovar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    if (!_noteOpen) {
                      setState(() => _noteOpen = true);
                      return;
                    }
                    widget.onDeny(
                      part.callId,
                      _noteController.text.trim().isEmpty
                          ? null
                          : _noteController.text.trim(),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BmoColors.accentRed,
                    side: BorderSide(
                      color: BmoColors.accentRed.withValues(alpha: 0.6),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(_noteOpen ? 'Confirmar negação' : 'Negar'),
                ),
              ],
            ),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  part.decision == AgentApprovalDecision.approved
                      ? 'aprovado'
                      : 'negado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: part.decision == AgentApprovalDecision.approved
                        ? BmoColors.accentGreen
                        : BmoColors.accentRed,
                  ),
                ),
                if (part.ignored)
                  Text(
                    'ignorada: você seguiu a conversa',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BmoColors.textMuted,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
