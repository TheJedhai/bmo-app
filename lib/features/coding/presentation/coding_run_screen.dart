import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/coding_run_providers.dart';
import '../data/models/coding_run.dart';
import 'widgets/coding_run_look.dart';

/// Detalhe de um run autônomo — `/coding/runs/:runId`.
class CodingRunScreen extends ConsumerWidget {
  final int runId;

  const CodingRunScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runAsync = ref.watch(codingRunProvider(runId));
    final eventsAsync = ref.watch(codingRunEventsProvider(runId));
    final eventsNotifier = ref.watch(codingRunEventsProvider(runId).notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _Header(runId: runId),
          Expanded(
            child: runAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
              error: (error, _) => Center(
                child: Text(
                  'falha ao carregar run: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: BmoColors.textSecondary,
                  ),
                ),
              ),
              data: (run) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  _Summary(run: run),
                  const SizedBox(height: 20),
                  Text(
                    'EVENTOS',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: BmoColors.accentGreen.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...eventsAsync.when(
                    loading: () => const [
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BmoColors.accentGreen,
                          ),
                        ),
                      ),
                    ],
                    error: (error, _) => [
                      Text(
                        'falha ao carregar eventos: $error',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: BmoColors.textSecondary,
                        ),
                      ),
                    ],
                    data: (events) => [
                      for (final event in events) _EventRow(event: event),
                      if (events.isEmpty)
                        const Text(
                          'Nenhum evento registrado',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: BmoColors.textMuted,
                          ),
                        ),
                      if (eventsNotifier.hasMore)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: eventsNotifier.loadMore,
                            child: const Text('carregar mais'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int runId;

  const _Header({required this.runId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (GoRouter.of(context).canPop()) {
                GoRouter.of(context).pop();
              } else {
                GoRouter.of(context).go('/coding');
              }
            },
            icon: const Icon(Icons.arrow_back, size: 20),
            color: BmoColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          Text(
            'RUN #$runId',
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
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CodingRun run;

  const _Summary({required this.run});

  @override
  Widget build(BuildContext context) {
    final look = codingRunLook(run.status);
    return Card(
      color: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: look.color.withValues(alpha: 0.25)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CodingRunStatusIcon(status: run.status, size: 18),
                const SizedBox(width: 10),
                Text(
                  look.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: look.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              run.prompt,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: BmoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _Field(label: 'branch', value: run.branch ?? '—'),
            _Field(label: 'commit', value: _shortSha(run.commitSha)),
            _Field(
              label: 'arquivos alterados',
              value: run.filesChanged.isEmpty
                  ? '—'
                  : '${run.filesChanged.length} (${run.filesChanged.take(3).join(', ')}'
                        '${run.filesChanged.length > 3 ? '…' : ''})',
            ),
            // Custo real do servidor. O `cost_usd` do Claude Code é só
            // estimativa e fica rotulado como tal.
            _Field(
              label: 'custo',
              value: formatComputedCost(run.costUsdComputed),
            ),
            if (run.costUsd != null)
              _Field(
                label: 'estimativa Claude Code',
                value: formatRunCost(run.costUsd),
              ),
            _Field(label: 'duração', value: formatRunDuration(run.durationMs)),
            _Field(
              label: 'quando',
              value: formatRunTimestamp(run.startedAt ?? run.createdAt),
            ),
            if (run.lastEvent != null && run.lastEvent!.isNotEmpty)
              _Field(label: 'último sinal', value: run.lastEvent!),
            if (run.usage != null) _Field(label: 'tokens', value: _usage(run.usage!)),
            _Field(
              label: 'juntado na base',
              value: run.isMerged
                  ? formatRunTimestamp(run.mergedAt)
                  : 'não',
            ),
            if (run.parentRunId != null && run.parentRunId! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      GoRouter.of(context).go('/coding/runs/${run.parentRunId}'),
                  child: Text('run pai #${run.parentRunId}'),
                ),
              ),
            // Motivo da falha (ausente em servidor antigo ou run sem erro).
            if (run.isFailure &&
                run.errorMessage != null &&
                run.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'erro',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                run.errorMessage!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: BmoColors.accentRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _usage(Map<String, dynamic> usage) {
    final input = usage['input_tokens'];
    final output = usage['output_tokens'];
    if (input == null && output == null) {
      return usage.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
    }
    return '${input ?? 0} entrada · ${output ?? 0} saída';
  }

  static String _shortSha(String? sha) =>
      sha == null ? '—' : (sha.length <= 7 ? sha : sha.substring(0, 7));
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: BmoColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CodingRunEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final payload = event.payload.isEmpty ? '' : jsonEncode(event.payload);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BmoColors.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${event.seq}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: BmoColors.accentGreen,
                  ),
                ),
              ),
              if (event.ts != null)
                Text(
                  formatRunTimestamp(event.ts),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: BmoColors.textMuted,
                  ),
                ),
            ],
          ),
          if (payload.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              payload,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: BmoColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
