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
/// O payload só traz `run_id`; o estado vem do [codingRunLiveProvider] (último
/// objeto vivo do run, guardado por id e alimentado por `coding.run.*` e pelo
/// `rich.update`). Sem estado vivo — run nunca visto neste app — cai no
/// REST (`codingRunProvider`), re-sincronizado no mount e no reconnect do SSE
/// (`sseGenerationProvider`).
class BmoRichCodingRunCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichCodingRunCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichCodingRunCard> createState() =>
      _BmoRichCodingRunCardState();
}

class _BmoRichCodingRunCardState extends ConsumerState<BmoRichCodingRunCard> {
  /// Status aplicado localmente pelo "Parar" (o SSE confirma depois).
  String? _statusOverride;

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
    // Sem estado vivo conhecido, busca o run por REST depois do primeiro
    // frame (não bloqueia o paint).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _runId <= 0) return;
      if (ref.read(codingRunLiveProvider(_runId)) == null) _resync();
    });
  }

  void _resync() {
    ref.invalidate(codingRunProvider(_runId));
  }

  Future<void> _kill() async {
    setState(() {
      _killing = true;
      _error = null;
    });
    try {
      await ref.read(codingClientProvider).killRun(_runId);
      // O evento de parado também chega; aplicar local evita o botão travado
      // se o SSE cair no meio.
      if (mounted) setState(() => _statusOverride = 'killed');
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

    final live = ref.watch(codingRunLiveProvider(runId));
    // Com estado vivo não vale a pena buscar o REST (o GET só existe para o
    // card remontado sem evento conhecido).
    final snapshot = live == null
        ? ref.watch(codingRunProvider(runId))
        : const AsyncValue<CodingRun>.loading();

    // Re-sync em cada reconexão do SSE (só quando não há estado vivo).
    ref.listen<int>(sseGenerationProvider, (previous, next) {
      if (previous != next && ref.read(codingRunLiveProvider(runId)) == null) {
        _resync();
      }
    });

    final run = snapshot.valueOrNull;
    if (run == null && live == null) {
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

    final rawStatus = _statusOverride ?? live?['status'];
    final status = codingRunStatusFrom(
      rawStatus is String ? rawStatus : run?.status.name,
    );
    final look = codingRunLook(status);
    final durationMs = _asInt(live?['duration_ms']) ?? run?.durationMs;
    final filesChanged =
        _asInt(live?['files_changed_count']) ?? run?.filesChangedCount;
    final branch = live?['branch']?.toString() ?? run?.branch;
    final commit = live?['commit_sha']?.toString() ?? run?.commitSha;
    // Custo real do servidor; o `cost_usd` do Claude Code não aparece aqui.
    final cost =
        _asDouble(live?['cost_usd_computed']) ?? run?.costUsdComputed;
    final mergedAt =
        live?['merged_at']?.toString() ?? run?.mergedAt?.toIso8601String();
    final isMerged = mergedAt != null && mergedAt.isNotEmpty;
    final parentRunId = _asInt(live?['parent_run_id']) ?? run?.parentRunId;
    final lastEvent = live?['last_event']?.toString() ?? run?.lastEvent;
    final failure = status == CodingRunStatus.failed ||
        status == CodingRunStatus.timeout;
    final errorMessage = failure
        ? (live?['error_message']?.toString() ?? run?.errorMessage)
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
