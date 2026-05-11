import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_message.dart';
import '../providers/chat_providers.dart';
import 'message_bubble.dart';

const _kAutoScrollTolerance = 150.0;

class ChatMessageList extends ConsumerStatefulWidget {
  final List<ChatMessage> messages;

  const ChatMessageList({super.key, required this.messages});

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList> {
  final _controller = ScrollController();
  ProviderSubscription<List<ChatMessage>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<List<ChatMessage>>(
      currentMessagesProvider,
      (prev, next) {
        final isFirstMessage = (prev == null || prev.isEmpty) && next.isNotEmpty;
        _scheduleAutoScroll(isFirstMessage: isFirstMessage);
      },
    );
    // Caso a tela monte com lista já populada (ex: hot reload).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (widget.messages.isEmpty) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sub?.close();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAutoScroll({required bool isFirstMessage}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final distanceToBottom = position.maxScrollExtent - position.pixels;
      if (!isFirstMessage && distanceToBottom > _kAutoScrollTolerance) return;
      _controller.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
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
        return MessageBubble(message: widget.messages[index]);
      },
    );
  }
}
