import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/bmo_theme.dart';

/// Composer do chat v2: mesma base do chat v1, mais `enabled`/`hintText` para
/// o estado de aprovação pendente.
class AgentInput extends StatefulWidget {
  final bool isStreaming;
  final bool enabled;
  final String hintText;
  final void Function(String text) onSend;
  final VoidCallback onCancel;

  /// Texto devolvido pelo notifier (envio que falhou); preenche o campo.
  final String? draft;

  const AgentInput({
    super.key,
    required this.isStreaming,
    required this.onSend,
    required this.onCancel,
    this.enabled = true,
    this.hintText = 'fala com o BMO...',
    this.draft,
  });

  @override
  State<AgentInput> createState() => _AgentInputState();
}

class _AgentInputState extends State<AgentInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(AgentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.draft;
    if (draft != null && draft != oldWidget.draft) {
      _controller.text = draft;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    if (widget.isStreaming || !widget.enabled) return KeyEventResult.handled;
    _handleSend();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.isStreaming || !widget.enabled;

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
                  hintText: widget.hintText,
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
          enabled: widget.enabled,
          onSend: _handleSend,
          onCancel: widget.onCancel,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final bool isStreaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _ActionButton({
    required this.isStreaming,
    required this.enabled,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final active = isStreaming || enabled;
    final color = isStreaming
        ? BmoColors.accentYellow
        : (enabled ? BmoColors.accentGreen : BmoColors.textMuted);
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
        onPressed: active ? (isStreaming ? onCancel : onSend) : null,
      ),
    );
  }
}
