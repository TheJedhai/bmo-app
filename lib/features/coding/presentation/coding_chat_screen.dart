import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/identity/identity_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../../chat/data/chat_message.dart';
import '../../chat/providers/chat_providers.dart';
import '../../chat/widgets/chat_input.dart';
import '../../chat/widgets/chat_message_list.dart';
import '../data/coding_chat_provider.dart';
import '../data/coding_providers.dart';
import '../data/models/coding_session.dart';

/// Tela de chat de uma conversa de coding — /coding/:projectId/:sessionId.
///
/// Reusa os widgets de chat ([ChatMessageList], [ChatInput]) e o cliente
/// HTTP/SSE da feature chat. A gestão de estado é feita pelo
/// [CodingChatNotifier], keyed pelo UUID da sessão de coding.
class CodingChatScreen extends ConsumerStatefulWidget {
  const CodingChatScreen({
    super.key,
    required this.projectId,
    required this.sessionId,
  });

  final int projectId;

  /// O `sessionId` do [CodingSession] (formato bmo-xxx), usado no
  /// POST /api/chat.
  final String sessionId;

  @override
  ConsumerState<CodingChatScreen> createState() => _CodingChatScreenState();
}

class _CodingChatScreenState extends ConsumerState<CodingChatScreen> {
  String? _resolvedUuid;
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    // Resolve o UUID (campo `id`) a partir do sessionId (bmo-xxx) que veio na
    // rota. Lê o valor atual imediatamente — o provider pode já ter sido
    // carregado pela tela de lista — e também escuta mudanças futuras.
    _resolveFrom(ref.read(sessionsProvider(widget.projectId)));
    ref.listenManual(sessionsProvider(widget.projectId), (prev, next) {
      _resolveFrom(next);
    });
  }

  @override
  void dispose() {
    ref.read(activeChatEchoProvider.notifier).state = null;
    super.dispose();
  }

  void _resolveFrom(AsyncValue<List<CodingSession>> async) {
    if (_resolvedUuid != null) return;
    async.whenData((sessions) {
      final session = sessions
          .where((s) => s.sessionId == widget.sessionId)
          .firstOrNull;
      if (session != null && session.id.isNotEmpty) {
        _resolvedUuid = session.id;
        if (!_historyLoaded) {
          _historyLoaded = true;
          ref
              .read(codingChatControllerProvider(session.id).notifier)
              .loadHistory();
        }
        // Configura callback de eco para rich question cards.
        final controller =
            ref.read(codingChatControllerProvider(session.id).notifier);
        ref.read(activeChatEchoProvider.notifier).state =
            (text) => controller.sendMessage(text, sessionId: widget.sessionId);
        // Força rebuild para sair do estado de loading.
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Gate opt-in
    final features = ref.watch(enabledFeaturesProvider);
    if (!features.contains('coding')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) GoRouter.of(context).go('/');
      });
      return const SizedBox.shrink();
    }

    // Mantém a subscription ao sessionsProvider ativa para o listenManual.
    final sessionsAsync = ref.watch(sessionsProvider(widget.projectId));

    if (_resolvedUuid == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: sessionsAsync.when(
            loading: () => const CircularProgressIndicator(
              strokeWidth: 2,
              color: BmoColors.accentGreen,
            ),
            error: (error, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 40, color: BmoColors.accentRed),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textSecondary,
                  ),
                ),
              ],
            ),
            data: (_) => const Text(
              'Conversa não encontrada',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final messages =
        ref.watch(codingChatControllerProvider(_resolvedUuid!));
    final controller =
        ref.read(codingChatControllerProvider(_resolvedUuid!).notifier);

    final last = messages.isEmpty ? null : messages.last;
    final isStreaming = last != null &&
        last.role == ChatRole.assistant &&
        last.status == ChatMessageStatus.streaming;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: BmoColors.screenBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/coding/${widget.projectId}');
            }
          },
          icon: const Icon(Icons.arrow_back, size: 20),
          color: BmoColors.textSecondary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        title: Text(
          'Conversa',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: BmoColors.accentGreen,
            shadows: [
              Shadow(
                color: BmoColors.accentGreen.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'manda uma mensagem aí',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: BmoColors.textSecondary,
                      ),
                    ),
                  )
                : ChatMessageList(messages: messages),
          ),
          Divider(
            color: BmoColors.textMuted.withValues(alpha: 0.2),
            height: 1,
            thickness: 1,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ChatInput(
              isStreaming: isStreaming,
              onSend: (text) => controller.sendMessage(
                text,
                sessionId: widget.sessionId,
              ),
              onCancel: controller.cancelCurrentRequest,
            ),
          ),
        ],
      ),
    );
  }
}
