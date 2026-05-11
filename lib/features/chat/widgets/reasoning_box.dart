import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';

class ReasoningBox extends StatefulWidget {
  final String reasoningText;
  final bool isStreaming;

  const ReasoningBox({
    super.key,
    required this.reasoningText,
    required this.isStreaming,
  });

  @override
  State<ReasoningBox> createState() => _ReasoningBoxState();
}

class _ReasoningBoxState extends State<ReasoningBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showContent = widget.isStreaming || _expanded;

    final headerLabel = widget.isStreaming ? 'pensando...' : 'ver pensamento';
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      color: BmoColors.textSecondary,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: widget.isStreaming
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text('💭', style: headerStyle),
                const SizedBox(width: 6),
                Expanded(child: Text(headerLabel, style: headerStyle)),
                if (!widget.isStreaming)
                  Icon(
                    _expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: BmoColors.textSecondary,
                  ),
              ],
            ),
          ),
          if (showContent && widget.reasoningText.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              widget.reasoningText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
