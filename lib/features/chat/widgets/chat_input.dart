import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';

class ChatInput extends ConsumerStatefulWidget {
  final bool isStreaming;
  final void Function(String text) onSend;
  final VoidCallback onCancel;

  const ChatInput({
    super.key,
    required this.isStreaming,
    required this.onSend,
    required this.onCancel,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    final shiftHeld = HardwareKeyboard.instance.isShiftPressed;
    if (shiftHeld) return KeyEventResult.ignored;
    if (widget.isStreaming) return KeyEventResult.handled;
    _handleSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.isStreaming;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !disabled,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: disabled ? BmoColors.textMuted : BmoColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'fala com o BMO...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textMuted,
                  ),
                  filled: true,
                  fillColor: BmoColors.screenBgElevated,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: BmoColors.textMuted, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: BmoColors.accentGreen,
                      width: 1.5,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: BmoColors.textMuted.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _ActionButton(
          isStreaming: widget.isStreaming,
          onSend: _handleSend,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _ActionButton({
    required this.isStreaming,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStreaming ? BmoColors.accentYellow : BmoColors.accentGreen;
    final icon = isStreaming ? Icons.stop : Icons.arrow_upward;
    final tooltip = isStreaming ? 'parar' : 'enviar';

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color.lerp(color, Colors.black, 0.2)!,
          width: 1,
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: const Color(0xFF0F1115)),
        onPressed: isStreaming ? onCancel : onSend,
      ),
    );
  }
}
