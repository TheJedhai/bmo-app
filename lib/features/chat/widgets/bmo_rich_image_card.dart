import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/events/events_provider.dart';
import '../../../core/events/rich_blocks_provider.dart';
import '../../../core/events/rich_blocks_state.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/bmo_rich_block.dart';

/// Renders a rich-content block of type "image" — now live.
///
/// Subscribes to [richBlocksProvider] keyed by [BmoRichBlock.blockId]. When
/// `rich.update` SSE events arrive (or the card re-syncs after reconnect) the
/// widget rebuilds in-place — no full-screen flicker.
///
/// States, in priority order:
/// 1. **Live generating** (progress < 100) → determinate progress bar.
/// 2. **Live generating** (progress == 100) → full bar + spinner "finalizando…"
///    (covers the VAE/save gap between generation done and file ready).
/// 3. **Live done** → the image, fetched from `/images/{imageId}/file`.
/// 4. **Live failed** → error message from the patch.
/// 5. **No live state** → static fallback (Image.network with loading/error
///    builders).  This covers images that were already `done` before this
///    session's SSE connection, or blocks that never receive `rich.update`.
class BmoRichImageCard extends ConsumerStatefulWidget {
  final BmoRichBlock block;

  const BmoRichImageCard({super.key, required this.block});

  @override
  ConsumerState<BmoRichImageCard> createState() => _BmoRichImageCardState();
}

class _BmoRichImageCardState extends ConsumerState<BmoRichImageCard> {
  bool _initialSyncDone = false;

  /// Incremented on every `generating → done` transition so the image URL and
  /// widget key change, bypassing Flutter's cached 404 from an earlier
  /// premature fetch (e.g. via [_buildStatic] or a too-early done patch).
  int _cacheBuster = 0;

  /// Tracks the previous live status so we can detect transitions to [RichBlockStatus.done]
  /// inside [build] without mutating state during the build phase itself —
  /// the actual [setState] is deferred via [WidgetsBinding.addPostFrameCallback].
  RichBlockStatus? _lastLiveStatus;

  // ---- image_id helpers ------------------------------------------------

  int get _payloadImageId {
    final v = widget.block.payload['image_id'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _imageUrlFor(int imageId) {
    return '${Env.bmoServerUrl}/api/v1/images/$imageId/file';
  }

  // ---- re-sync ---------------------------------------------------------

  /// Best-effort one-shot sync from the REST API.  Covers both the initial
  /// mount and SSE reconnect gaps.
  Future<void> _syncIfNeeded() async {
    final imageId = _payloadImageId;
    if (imageId <= 0) return;
    await ref
        .read(richBlocksProvider.notifier)
        .syncImageBlock(widget.block.blockId, imageId);
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

  // ---- build -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // 1. Live state for this block (if any).
    final richStates = ref.watch(richBlocksProvider);
    final live = richStates[widget.block.blockId];

    // 2. Detect transitions to `done` so we can bust the image cache.
    //    Deferred via post-frame — no setState during build.
    if (live?.status == RichBlockStatus.done &&
        _lastLiveStatus != RichBlockStatus.done) {
      _lastLiveStatus = live?.status;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _cacheBuster++);
      });
    } else if (live?.status != RichBlockStatus.done) {
      _lastLiveStatus = live?.status;
    }

    // 3. Watch SSE generation so we can re-sync on reconnect.
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

  // ---- live-state dispatch ---------------------------------------------

  Widget _buildFromLive(RichBlockState? live) {
    if (live == null) return _buildStatic();

    switch (live.status) {
      case RichBlockStatus.generating:
        return _buildProgress(live.progress);

      case RichBlockStatus.done:
        final imageId = live.imageId != null && live.imageId! > 0
            ? live.imageId!
            : _payloadImageId;
        if (imageId <= 0) return _buildStatic();
        return _buildImage(imageId);

      case RichBlockStatus.failed:
        return _buildError(live.error);

      // Question-only statuses — not applicable to image blocks.
      case RichBlockStatus.pending:
      case RichBlockStatus.answered:
      case RichBlockStatus.cancelled:
        return _buildStatic();
    }
  }

  // ---- progress bar ----------------------------------------------------

  Widget _buildProgress(int progress) {
    final clamped = progress.clamp(0, 100);
    final isFinalizing = clamped >= 100;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: isFinalizing ? 1.0 : clamped / 100.0,
                  minHeight: 6,
                  color: BmoColors.accentGreen,
                  backgroundColor:
                      BmoColors.screenBgElevated,
                ),
              ),
              const SizedBox(height: 10),
              // Label + optional spinner
              if (isFinalizing)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BmoColors.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Finalizando...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BmoColors.accentGreen,
                          ),
                    ),
                  ],
                )
              else
                Text(
                  'Gerando imagem... $clamped%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BmoColors.textSecondary,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- image -----------------------------------------------------------

  Widget _buildImage(int imageId) {
    // Cache-buster: a new query param on every generating→done transition
    // means Flutter's NetworkImage sees a different URL and won't serve a
    // previously cached 404.  Combined with the [ValueKey] below this also
    // forces a fresh widget element, in case the image provider itself holds
    // on to the error.
    final url = '${_imageUrlFor(imageId)}?cb=$_cacheBuster';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        key: ValueKey('img-$imageId-done-$_cacheBuster'),
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading(context, loadingProgress);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildImageError(imageId, error),
      ),
    );
  }

  Widget _buildImageError(int imageId, Object error) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined,
                  size: 28, color: BmoColors.accentYellow),
              const SizedBox(height: 6),
              Text(
                'Erro ao carregar imagem',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BmoColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // Increment cache-buster to force a fresh fetch on retry.
                  setState(() => _cacheBuster++);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  'Tentar novamente',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BmoColors.accentGreen,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- error -----------------------------------------------------------

  Widget _buildError(String? error) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 28, color: BmoColors.accentYellow),
              const SizedBox(height: 6),
              Text(
                error ?? 'Erro ao gerar imagem',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BmoColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- static fallback (no live state) ---------------------------------

  /// Identical to the original static card — fetches the image directly and
  /// shows a loading placeholder while it loads.  Covers images that were
  /// already `done` before this session's SSE connection started.
  Widget _buildStatic() {
    final url = _payloadImageId > 0 ? _imageUrlFor(_payloadImageId) : '';
    if (url.isEmpty) return _buildPlaceholder(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading(context, loadingProgress);
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildLoading(BuildContext context, ImageChunkEvent progress) {
    final total = progress.expectedTotalBytes;
    final loaded = progress.cumulativeBytesLoaded;
    final fraction = total != null && total > 0 ? loaded / total : null;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2,
                color: BmoColors.accentGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gerando imagem...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 32, color: BmoColors.textMuted),
            const SizedBox(height: 6),
            Text(
              'Gerando imagem...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BmoColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
