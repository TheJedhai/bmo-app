import 'package:flutter/material.dart';

import '../data/agent_message.dart';
import 'agent_message_bubble.dart';

/// Lista com autoscroll: acompanha o streaming enquanto o usuário está perto
/// do fim (mesma tolerância do chat v1).
class AgentMessageList extends StatefulWidget {
  final List<AgentMessage> messages;
  final bool streaming;
  final void Function(String callId) onApprove;
  final void Function(String callId, String? note) onDeny;

  const AgentMessageList({
    super.key,
    required this.messages,
    required this.onApprove,
    required this.onDeny,
    this.streaming = false,
  });

  @override
  State<AgentMessageList> createState() => _AgentMessageListState();
}

class _AgentMessageListState extends State<AgentMessageList> {
  static const _tolerance = 150.0;

  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void didUpdateWidget(covariant AgentMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.messages, widget.messages)) return;
    final grew = widget.messages.length > oldWidget.messages.length;
    _scheduleScroll(force: grew);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!mounted || !_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  void _scheduleScroll({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final distance = position.maxScrollExtent - position.pixels;
      if (!force && distance > _tolerance) return;
      _controller.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        return AgentMessageBubble(
          message: message,
          streaming: widget.streaming && index == widget.messages.length - 1,
          onApprove: widget.onApprove,
          onDeny: widget.onDeny,
        );
      },
    );
  }
}
