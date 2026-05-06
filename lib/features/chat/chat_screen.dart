import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bmo_theme.dart';
import 'data/chat_event.dart';
import 'providers/chat_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  String _accumulatedText = '';
  String? _currentMessageId;
  String _status = 'idle';
  int _eventCount = 0;
  StreamSubscription<ChatEvent>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _subscription?.cancel();

    setState(() {
      _accumulatedText = '';
      _currentMessageId = null;
      _status = 'sending...';
      _eventCount = 0;
    });

    final client = ref.read(bmoChatClientProvider);
    final stream = client.sendMessage(
      sessionId: 'flutter-test-001',
      text: text,
    );

    _subscription = stream.listen(
      (event) {
        setState(() {
          _eventCount++;
          switch (event) {
            case ResponseCreated():
              _status = 'created';
            case ResponseInProgress():
              _status = 'in_progress';
            case MessageStarted(:final messageId, :final messageType):
              if (messageType == 'message') {
                _currentMessageId = messageId;
              }
            case TextDelta(:final messageId, :final text):
              if (messageId == _currentMessageId) {
                _accumulatedText += text;
                _scrollToBottom();
              }
            case MessageCompleted():
              // texto já acumulado pelos deltas
              break;
            case ResponseCompleted():
              _status = 'completed';
            case StreamError(:final error):
              _status = 'error: $error';
            case UnknownEvent():
              // já logado no client
              break;
          }
        });
      },
      onError: (e) {
        setState(() {
          _status = 'error: $e';
        });
      },
    );

    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('TESTE STREAMING', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SelectableText(
                _accumulatedText.isEmpty ? '(sem texto ainda)' : _accumulatedText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _accumulatedText.isEmpty
                      ? BmoColors.textMuted
                      : BmoColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'status: $_status',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'mensagem...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: BmoColors.textMuted,
                    ),
                    filled: true,
                    fillColor: BmoColors.screenBgElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _send,
                child: const Text('enviar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'eventos: $_eventCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
