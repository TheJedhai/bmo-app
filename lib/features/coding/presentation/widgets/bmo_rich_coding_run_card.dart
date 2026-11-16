import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bmo_app/core/events/events_provider.dart';
import 'package:bmo_app/core/navigation/app_router.dart';
import 'package:bmo_app/core/theme/bmo_theme.dart';
import 'package:bmo_app/features/rich_blocks/data/bmo_rich_block.dart';
import 'package:bmo_app/features/rich_blocks/widgets/bmo_clamped_text.dart';

import '../../data/coding_providers.dart';
import '../../data/coding_run_providers.dart';
import '../../data/models/coding_run.dart';
import 'coding_run_look.dart';

/// Card do bloco rico `coding_run` (run autônomo de um projeto).
///
/// O payload só traz `run_id`; o estado vem do REST (`codingRunProvider`) e é
/// sobreposto pelos patches de `rich.update` do `/api/v1/stream`. O EventBus é
/// efêmero, então o card re-sincroniza por REST no mount e no reconnect do SSE
/// (`sseGenerationProvider`), como o card de imagem.
class BmoRichCodingRunCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichCodingRunCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichCodingRunCard> createState() =>
      _BmoRichCodingRunCardState();
}

class _BmoRichCodingRunCardState extends ConsumerState<BmoRichCodingRunCard> {
  /// Campos recebidos por `rich.update` depois do último snapshot REST.
  Map<String, dynamic> _live = {};

  bool _killing = false;
  String? _error;

  int get _runId {
    final fromPayload = widget.block.payload['run_id'];
    if (fromPayload is int) return fromPayload;
    if (fromPayload is String) return int.tryParse(fromPayload) ?? 0;
    // Fallback pelo contrato do block_id: `coding-run-{run_id}`.
    return int.tryParse(widget.block.blockId.replaceFirst('coding-run-', '')) ??
        0;
  }

  @override
  void initState() {
    super.initState();
    // Re-sync por REST depois do primeiro frame (não bloqueia o paint).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _runId > 0) _resync();
    });
  }

  void _resync() {
    ref.invalidate(codingRunProvider(_runId));
  }

  void _applyLive(Map<String, dynamic> patch) {
    if (!mounted) return;
    setState(() => _live = {..._live, ...patch});
  }

  Future<void> _kill() async {
    setState(() {
      _killing = true;
      _error = null;
    });
    try {
      await ref.read(codingClientProvider).killRun(_runId);
      // O `rich.update` de parado também chega; aplicar local evita o botão
      // travado se o SSE cair no meio.
      _applyLive({'status': 'killed'});
    } catch (e) {
      if (mounted) setState(() => _error = 'falha ao parar: $e');
    } finally {
      if (mounted) setState(() => _killing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runId = _runId;
    if (runId <= 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'run de coding sem id',
          style: TextStyle(fontFamily: 'Inter', color: BmoColors.textMuted),
        ),
      );
    }

    final snapshot = ref.watch(codingRunProvider(runId));

    // Patches em tempo real (o listener do app já assina o stream; aqui só
    // filtramos o bloco deste card).
    ref.listen<AsyncValue<Map<String, dynamic>>>(eventsStreamProvider, (
      previous,
      next,
    ) {
      final event = next.valueOrNull;
      if (event == null) return;
      if (event['type'] != 'rich.update') return;
      if (event['block_id'] != widget.block.blockId) return;
      final patch = event['patch'];
      if (patch is Map) _applyLive(Map<String, dynamic>.from(patch));
    });

    // Re-sync em cada reconexão do SSE.
    ref.listen<int>(sseGenerationProvider, (previous, next) {
      if (previous != next) _resync();
    });

    // Snapshot novo do REST invalida os patches antigos.
    ref.listen<AsyncValue<CodingRun>>(codingRunProvider(runId), (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _live = {});
        });
      }
    });

    final run = snapshot.valueOrNull;
    if (run == null && _live.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BmoColors.screenBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: BmoColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BmoColors.accentGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.hasError ? 'run indisponível' : 'carregando run...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final rawStatus = _live['status'];
    final status = codingRunStatusFrom(
      rawStatus is String ? rawStatus : run?.status.name,
    );
    final look = codingRunLook(status);
    final durationMs = _asInt(_live['duration_ms']) ?? run?.durationMs;
    final filesChanged =
        _asInt(_live['files_changed_count']) ?? run?.filesChanged.length;
    final branch = _live['branch']?.toString() ?? run?.branch;
    final commit = _live['commit_sha']?.toString() ?? run?.commitSha;
    // Custo real do servidor; o `cost_usd` do Claude Code não aparece aqui.
    final cost =
        _asDouble(_live['cost_usd_computed']) ?? run?.costUsdComputed;
    final mergedAt = _live['merged_at']?.toString() ?? run?.mergedAt?.toIso8601String();
    final isMerged = mergedAt != null && mergedAt.isNotEmpty;
    final parentRunId =
        _asInt(_live['parent_run_id']) ?? run?.parentRunId;
    final lastEvent =
        _live['last_event']?.toString() ?? run?.lastEvent;
    final failure = status == CodingRunStatus.failed ||
        status == CodingRunStatus.timeout;
    final errorMessage = failure
        ? (_live['error_message']?.toString() ?? run?.errorMessage)
        : null;
    final active =
        status == CodingRunStatus.queued || status == CodingRunStatus.running;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: look.color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CodingRunStatusIcon(status: status),
                const SizedBox(width: 8),
                Text(
                  look.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: look.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  formatRunDuration(durationMs),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
                ),
              ],
            ),
            if (lastEvent != null && lastEvent.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                lastEvent,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
              ),
            ],
            // Motivo da falha vindo do servidor (ausente em servidor antigo).
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                errorMessage,
                maxLines: 3,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (branch != null && branch.isNotEmpty)
                  _Meta(icon: Icons.call_split, text: branch, maxWidth: 160),
                if (commit != null && commit.isNotEmpty)
                  _Meta(icon: Icons.commit, text: _shortSha(commit)),
                _Meta(
                  icon: Icons.description_outlined,
                  text: '${filesChanged ?? 0} arquivo(s)',
                ),
                _Meta(
                  icon: Icons.payments_outlined,
                  text: formatComputedCost(cost),
                ),
                if (isMerged)
                  const _Meta(icon: Icons.merge_type, text: 'juntado na base'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              BmoClampedText(
                _error!,
                maxLines: 2,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: BmoColors.accentRed),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (active)
                  OutlinedButton(
                    onPressed: _killing ? null : _kill,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BmoColors.accentRed,
                      side: BorderSide(
                        color: BmoColors.accentRed.withValues(alpha: 0.6),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Parar'),
                  ),
                if (active) const SizedBox(width: 8),
                TextButton(
                  onPressed: () => appRouter.go('/coding/runs/$runId'),
                  child: const Text('Detalhes'),
                ),
                if (parentRunId != null && parentRunId > 0)
                  TextButton(
                    onPressed: () => appRouter.go('/coding/runs/$parentRunId'),
                    child: Text('run pai #$parentRunId'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortSha(String sha) =>
      sha.length <= 7 ? sha : sha.substring(0, 7);

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final double? maxWidth;

  const _Meta({required this.icon, required this.text, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: BmoColors.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: BmoColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
