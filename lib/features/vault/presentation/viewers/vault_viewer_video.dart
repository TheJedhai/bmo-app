/// In-app video viewer for vault items.
///
/// Fetches the full video via [VaultRepository.downloadItem], creates a blob
/// URL, and embeds a native `<video>` element via [HtmlElementView].
/// **Zero additional dependencies** — the browser's video player handles all
/// codecs, controls, seek, and fullscreen natively.
///
/// ## Why native <video> instead of video_player?
/// video_player is redundant on web — it's just a wrapper around <video>.
/// Using the element directly:
/// - Zero dependencies
/// - Full codec support (whatever Chrome supports: H.264, VP8, VP9, AV1, etc.)
/// - Native controls, seek, and fullscreen
/// - Same user experience as any web video
///
/// ## Memory / platform view lifecycle
/// Flutter's [platformViewRegistry] has no `unregisterFactory` — once a factory
/// is registered for a viewType, it stays in the registry forever.  If the
/// factory closure captures the `<video>` element directly, that element (and
/// its decoded frame buffers) can never be GC'd.
///
/// **Fix**: the factory captures only a *string key* (the viewType).  Video
/// elements live in a top-level `_videoElements` map.  On dispose, the element
/// is removed from the map → the factory can no longer reach it → GC collects
/// the ~250 MiB of decoded frames.
///
/// ViewType IDs use a monotonically-increasing counter so each instance gets a
/// unique key (avoiding the `registerViewFactory` collision that a static
/// viewType would cause on the second opening).
///
/// ## Security
/// - Decrypted content lives only as a blob URL while the viewer is open.
/// - Blob URL revoked on close; plaintext reference discarded.
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_client.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';

// ---------------------------------------------------------------------------
// Global video element registry
// ---------------------------------------------------------------------------

/// Maps viewType → live `<video>` element so the platform view factory
/// can look up the element without capturing it in a closure.
final _videoElements = <String, html.VideoElement>{};

int _nextViewId = 0;

/// Creates a unique viewType for a single viewer instance.
String _nextVideoViewType() => 'vault-video-${_nextViewId++}';

/// Platform view factory.  Captures only [viewType] (a short string), NOT
/// the video element.  Looks up the global [_videoElements] map so that
/// removing the element from the map on dispose severs the last reference.
html.VideoElement _videoPlatformFactory(int viewId, String viewType) {
  return _videoElements[viewType]!;
}

// ============================================================
// Viewer dialog
// ============================================================

class VaultVideoViewer extends ConsumerStatefulWidget {
  final VaultItemDecrypted item;
  final VaultSession session;
  final VaultRepository repo;
  final bool isMobile;

  /// Called when the user taps "Baixar" after a memory error.
  /// If null, the download button is hidden and only retry is shown.
  final VoidCallback? onDownload;

  const VaultVideoViewer({
    super.key,
    required this.item,
    required this.session,
    required this.repo,
    required this.isMobile,
    this.onDownload,
  });

  @override
  ConsumerState<VaultVideoViewer> createState() => _VaultVideoViewerState();
}

class _VaultVideoViewerState extends ConsumerState<VaultVideoViewer> {
  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  bool _isMemoryError = false;
  String? _blobUrl;
  late final String _viewType;

  html.VideoElement? _videoElement;

  @override
  void initState() {
    super.initState();
    _viewType = _nextVideoViewType();
    _load();
  }

  Future<void> _load() async {
    // Clean up any state from a previous attempt before starting fresh.
    _cleanupVideoElement();
    _cleanupBlobUrl();
    _isMemoryError = false;

    try {
      final bytes = await widget.repo.downloadItem(
        widget.session.vaultId,
        widget.session.dek,
        widget.item.id,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;

      // Wrap blob creation in try-catch for memory errors.
      String? blobUrl;
      try {
        final blob = html.Blob([bytes], widget.item.mimeType);
        blobUrl = html.Url.createObjectUrl(blob);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isMemoryError = true;
          _error = 'Não foi possível carregar — arquivo grande demais '
              'para a memória disponível.\nUse a opção Baixar.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) {
        // Widget was disposed while creating blob — revoke it immediately.
        html.Url.revokeObjectUrl(blobUrl);
        return;
      }

      // Create the video element.
      final video = html.VideoElement()
        ..src = blobUrl
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.maxHeight = '100%'
        ..setAttribute('playsinline', 'true');

      _videoElement = video;
      _videoElements[_viewType] = video;

      // Register the platform view factory.  The closure captures only
      // [_viewType] (a short string), NOT [video].  The factory looks up
      // the global [_videoElements] map at call time.  When this viewer
      // is disposed, the entry is removed from [_videoElements] → the
      // factory can no longer reach the element → GC collects the frames.
      // ignore: unnecessary_lambdas
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => _videoPlatformFactory(viewId, _viewType),
      );

      setState(() {
        _blobUrl = blobUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Clean up any partially-created resources on error.
      _cleanupVideoElement();
      _cleanupBlobUrl();

      final msg = e.toString().toLowerCase();
      if (msg.contains('memory') ||
          msg.contains('allocation') ||
          msg.contains('out of') ||
          msg.contains('overflow') ||
          msg.contains('array length')) {
        setState(() {
          _isMemoryError = true;
          _error = 'Não foi possível carregar — arquivo grande demais '
              'para a memória disponível.\nUse a opção Baixar.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is VaultApiException) return 'Erro do servidor (${e.statusCode}).';
    return e.toString();
  }

  void _requestFullscreen() {
    _videoElement?.requestFullscreen();
  }

  // ---------------------------------------------------------------------------
  // Resource cleanup
  // ---------------------------------------------------------------------------

  /// Revokes the blob URL and clears the reference.
  void _cleanupBlobUrl() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
      _blobUrl = null;
    }
  }

  /// Properly tears down the native `<video>` element so that media buffers
  /// are released back to the browser:
  /// 1. Pause playback
  /// 2. Clear `src` + call `load()` to reset the media pipeline (releases
  ///    decoded frame buffers held by the element)
  /// 3. Detach from DOM if still attached
  /// 4. Remove from the global [_videoElements] map so the platform view
  ///    factory (still registered in [platformViewRegistry]) no longer
  ///    reaches this element → GC can collect it
  void _cleanupVideoElement() {
    final v = _videoElement;
    if (v == null) return;

    try {
      v.pause();
      v.src = '';
      v.load();
      if (v.parentNode != null) {
        v.remove();
      }
    } catch (_) {
      // Best-effort cleanup — never throw during dispose.
    }

    _videoElements.remove(_viewType);
    _videoElement = null;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultSessionProvider, (prev, next) {
      if (next == null) {
        _videoElement?.pause();
        html.document.exitFullscreen();
        Navigator.of(context).pop();
      }
    });

    final effectiveMobile = widget.isMobile;

    return Dialog(
      backgroundColor: BmoColors.screenBg,
      shape: effectiveMobile
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
      insetPadding: effectiveMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: effectiveMobile ? double.infinity : 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _ViewerHeader(
              title: widget.item.fileName,
              actions: [
                if (!_isLoading && _error == null)
                  _HeaderIconButton(
                    icon: Icons.fullscreen,
                    tooltip: 'Tela cheia',
                    onPressed: _requestFullscreen,
                  ),
                _HeaderIconButton(
                  icon: Icons.close,
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Content
            Flexible(
              child: _buildContent(effectiveMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: BmoColors.accentGreen),
            const SizedBox(height: 16),
            const Text('Decifrando…',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: BmoColors.textSecondary)),
            if (_progress > 0) ...[
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: BmoColors.textMuted)),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 32),
              const SizedBox(height: 8),
              const Text('falha ao carregar',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.redAccent)),
              const SizedBox(height: 4),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: BmoColors.textMuted),
                  maxLines: 5),
              const SizedBox(height: 12),
              // For memory errors, offer download as the primary action.
              // Retry is only shown for transient (non-memory) errors.
              if (_isMemoryError && widget.onDownload != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: BmoColors.accentGreen),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onDownload!.call();
                  },
                  child: const Text('Baixar',
                      style: TextStyle(color: BmoColors.screenBg)),
                )
              else
                TextButton(
                  onPressed: _load,
                  child: const Text('tentar novamente'),
                ),
            ],
          ),
        ),
      );
    }

    if (_blobUrl == null) return const SizedBox.shrink();

    // Native browser video player
    return Container(
      color: Colors.black,
      child: HtmlElementView(viewType: _viewType),
    );
  }

  @override
  void dispose() {
    _cleanupVideoElement();
    _cleanupBlobUrl();
    super.dispose();
  }
}

// ============================================================
// Shared widgets
// ============================================================

class _ViewerHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _ViewerHeader({required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: BmoColors.textMuted, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BmoColors.textPrimary,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: BmoColors.textSecondary),
        ),
      ),
    );
  }
}
