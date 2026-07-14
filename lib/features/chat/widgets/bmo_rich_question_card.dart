import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/events/events_provider.dart';
import '../../../core/events/rich_blocks_provider.dart';
import '../../../core/events/rich_blocks_state.dart';
import '../../../core/http/client_factory.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/bmo_rich_block.dart';
import '../providers/chat_providers.dart';

/// Renders a rich-content block of type "question" — an interactive prompt
/// with selectable options the user can click to answer.
///
/// Subscribes to [richBlocksProvider] keyed by [BmoRichBlock.blockId]. When
/// `rich.update` SSE events arrive (or the card re-syncs after reconnect) the
/// widget rebuilds in-place — no full-screen flicker.
///
/// States, in priority order:
/// 1. **pending** (or no live state, unsynced) → prompt + clickable option
///    buttons.
/// 2. **answered** → terminal: shows the chosen-option label, no buttons.
/// 3. **cancelled** → terminal: "Pergunta expirada", no buttons.
class BmoRichQuestionCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichQuestionCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichQuestionCard> createState() =>
      _BmoRichQuestionCardState();
}

class _BmoRichQuestionCardState extends ConsumerState<BmoRichQuestionCard> {
  bool _initialSyncDone = false;

  /// True while a POST to /questions/{id}/answer is in-flight.
  /// Disables buttons optimistically to prevent double-clicks.
  bool _submitting = false;

  /// Non-null when the last submission failed with a network/unexpected error.
  /// Cleared on the next submission attempt.
  String? _errorMessage;

  // ---- payload helpers ----------------------------------------------------

  int get _payloadQuestionId {
    final v = widget.block.payload['question_id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String get _payloadPrompt {
    final v = widget.block.payload['prompt'];
    if (v is String) return v;
    return '';
  }

  List<_QuestionOption> get _payloadOptions {
    final v = widget.block.payload['options'];
    if (v is List) {
      return v
          .whereType<Map<String, dynamic>>()
          .map((o) => _QuestionOption(
                label: (o['label'] as String?) ?? '',
                value: (o['value'] as String?) ?? '',
              ))
          .where((o) => o.value.isNotEmpty)
          .toList();
    }
    return [];
  }

  // ---- re-sync ------------------------------------------------------------

  /// Best-effort one-shot sync from the REST API.  Covers both the initial
  /// mount and SSE reconnect gaps.
  Future<void> _syncIfNeeded() async {
    final questionId = _payloadQuestionId;
    if (questionId <= 0) return;
    await ref
        .read(richBlocksProvider.notifier)
        .syncQuestionBlock(widget.block.blockId, questionId);
  }

  @override
  void initState() {
    super.initState();
    // Trigger re-sync after the first frame so we don't block first paint.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _syncIfNeeded();
      if (mounted) setState(() => _initialSyncDone = true);
    });
  }

  // ---- answer submission --------------------------------------------------

  Future<void> _submitAnswer(String value) async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final questionId = _payloadQuestionId;
    final client = ref.read(httpClientProvider);

    try {
      final url = Uri.parse(
        '${Env.bmoServerUrl}/api/v1/questions/$questionId/answer',
      );
      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'value': value}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Success — the SSE rich.update will arrive and apply the terminal
        // state.  Apply the patch locally as a fallback in case SSE fails,
        // so the card doesn't stay stuck in submitting forever.
        ref.read(richBlocksProvider.notifier).applyPatch(
              widget.block.blockId,
              {'status': 'answered', 'chosen_value': value},
            );

        // If the block payload says there's no follow-up action, echo the
        // chosen option label as a user chat message so the assistant can
        // respond to it in the current conversation.
        final hasAction = widget.block.payload['has_action'] as bool? ?? false;
        if (!hasAction) {
          _sendAsChatMessage(value);
        }
      } else if (response.statusCode == 409) {
        // Already answered or cancelled — sync to discover the real state
        // and render it.  Don't show an error; the real state is what matters.
        await _syncIfNeeded();
      } else {
        // Unexpected status — re-enable buttons and show feedback.
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _errorMessage = 'Erro ao enviar resposta (${response.statusCode})';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Erro de conexão. Tente novamente.';
      });
    }
  }

  // ---- chat message echo ---------------------------------------------------

  /// Looks up the label for [value] in the payload options and, if a chat
  /// session is currently selected, sends it as a user message through the
  /// same streaming path used by the chat input (POST /api/chat with SSE,
  /// X-User-Id header, etc.).
  void _sendAsChatMessage(String value) {
    final label = _payloadOptions
        .where((o) => o.value == value)
        .map((o) => o.label)
        .firstOrNull;
    final text = (label != null && label.isNotEmpty) ? label : value;

    final selectedId = ref.read(selectedConversationIdProvider);
    if (selectedId == null) return;

    ref.read(chatControllerProvider(selectedId).notifier).sendMessage(text);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // 1. Live state for this block (if any).
    final richStates = ref.watch(richBlocksProvider);
    final live = richStates[widget.block.blockId];

    // 2. Watch SSE generation so we can re-sync on reconnect.
    ref.listen(sseGenerationProvider, (prev, next) {
      if (prev != next && _initialSyncDone) {
        _syncIfNeeded();
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _buildFromLive(live),
    );
  }

  // ---- live-state dispatch ------------------------------------------------

  Widget _buildFromLive(RichBlockState? live) {
    if (live == null) return _buildPending();

    switch (live.status) {
      case RichBlockStatus.pending:
        return _buildPending();

      case RichBlockStatus.answered:
        return _buildAnswered(live.chosenValue);

      case RichBlockStatus.cancelled:
        return _buildCancelled();

      // Image-only statuses — not applicable to question blocks.
      // Treat as pending so the card still renders the prompt + buttons.
      case RichBlockStatus.generating:
      case RichBlockStatus.done:
      case RichBlockStatus.failed:
        return _buildPending();
    }
  }

  // ---- pending ------------------------------------------------------------

  Widget _buildPending() {
    final prompt = _payloadPrompt;
    final options = _payloadOptions;
    final disabled = _submitting;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prompt.isNotEmpty) ...[
            Text(
              prompt,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
          ],
          if (options.isEmpty)
            Text(
              'Nenhuma opção disponível',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.textMuted,
                  ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options
                  .map((opt) => OutlinedButton(
                        onPressed: disabled
                            ? null
                            : () => _submitAnswer(opt.value),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BmoColors.accentGreen,
                          side: BorderSide(
                            color: disabled
                                ? BmoColors.textMuted.withValues(alpha: 0.3)
                                : BmoColors.accentGreen.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          opt.label.isNotEmpty ? opt.label : opt.value,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: disabled
                                        ? BmoColors.textMuted
                                        : BmoColors.textPrimary,
                                  ),
                        ),
                      ))
                  .toList(),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentYellow,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- answered -----------------------------------------------------------

  Widget _buildAnswered(String? chosenValue) {
    final options = _payloadOptions;
    final label = options
        .where((o) => o.value == chosenValue)
        .map((o) => o.label)
        .firstOrNull;
    final display = label ?? chosenValue ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 20, color: BmoColors.accentGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display.isNotEmpty ? 'Você escolheu: $display' : 'Respondido',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- cancelled ----------------------------------------------------------

  Widget _buildCancelled() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined,
              size: 20, color: BmoColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pergunta expirada',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BmoColors.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parsed option from the question payload.
class _QuestionOption {
  final String label;
  final String value;
  const _QuestionOption({required this.label, required this.value});
}
