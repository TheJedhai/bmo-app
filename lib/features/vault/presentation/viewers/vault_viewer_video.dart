// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

/// In-app video viewer for vault items.
///
/// Fetches the full video via [VaultRepository.downloadItem], decrypts it,
/// creates a blob URL, and plays it with the [video_player] package.
///
/// ## Why video_player instead of manual <video>
/// The previous manual approach (HtmlElementView + platformViewRegistry)
/// leaked ~250 MB per open/close cycle because platformViewRegistry has no
/// `unregisterViewFactory`.  video_player manages the platform view lifecycle
/// internally — when the [VideoPlayer] widget is removed from the tree, the
/// plugin tears down the underlying `<video>` element, releases media buffers,
/// and the platform view is disposed by the Flutter engine.
///
/// ## Security
/// - Decrypted content lives only as a blob URL while the viewer is open.
/// - Blob URL revoked on close; plaintext reference discarded.
library;

import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_client.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';

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
  VideoPlayerController? _controller;
  bool _isFullscreenOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Clean up any state from a previous attempt before starting fresh.
    await _disposeController();
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

      // Create video_player controller pointing at the blob URL.
      // video_player_web creates a <video> element internally and manages
      // its lifecycle — when this widget is disposed and the platform view
      // is removed, the plugin tears down the element and releases buffers.
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(blobUrl),
      );

      try {
        await controller.initialize();
      } catch (e) {
        if (!mounted) return;
        controller.dispose();
        html.Url.revokeObjectUrl(blobUrl);
        setState(() {
          _error = _friendlyError(e);
          _isLoading = false;
        });
        return;
      }

      if (!mounted) {
        controller.dispose();
        html.Url.revokeObjectUrl(blobUrl);
        return;
      }

      _controller = controller;
      _blobUrl = blobUrl;

      // Listen for playback state changes to rebuild controls.
      _controller!.addListener(_onControllerUpdate);

      setState(() {
        _isLoading = false;
      });

      // Start playback immediately.
      _controller!.play();
    } catch (e) {
      if (!mounted) return;
      // Clean up any partially-created resources on error.
      await _disposeController();
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

  void _onControllerUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  String _friendlyError(Object e) {
    if (e is VaultApiException) return 'Erro do servidor (${e.statusCode}).';
    return e.toString();
  }

  // ---------------------------------------------------------------------------
  // Playback controls
  // ---------------------------------------------------------------------------

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  void _seekTo(double value) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.seekTo(Duration(milliseconds: value.round()));
  }

  // ---------------------------------------------------------------------------
  // Fullscreen
  // ---------------------------------------------------------------------------

  void _openFullscreen() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (_isFullscreenOpen) return;

    // Pause in the inline player; the fullscreen player starts fresh.
    final wasPlaying = c.value.isPlaying;
    final position = c.value.position;
    c.pause();

    _isFullscreenOpen = true;
    Navigator.of(context)
        .push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _VideoFullscreenOverlay(
          controller: c,
          fileName: widget.item.fileName,
          startPosition: position,
          wasPlaying: wasPlaying,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    )
        .then((_) {
      if (mounted) {
        _isFullscreenOpen = false;
        // Refresh inline player state after returning from fullscreen.
        setState(() {});
      }
    });
  }

  /// Closes this viewer — first the fullscreen overlay (if open), then
  /// the dialog itself. Called when [vaultSessionProvider] becomes `null`
  /// (vault locked via tab switch, explicit lock, or inactivity timer).
  void _closeOnLock() {
    if (_isFullscreenOpen) {
      Navigator.of(context).pop(); // fullscreen overlay
    }
    Navigator.of(context).pop(); // this dialog
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

  /// Disposes the [VideoPlayerController] — the managed teardown that
  /// releases the underlying `<video>` element and its decoded frame buffers.
  Future<void> _disposeController() async {
    final c = _controller;
    if (c == null) return;
    _controller = null;
    c.removeListener(_onControllerUpdate);
    await c.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Close this viewer when the vault locks (session → null).
    // Must be called from build, not initState — Riverpod requires
    // ref.listen to be registered during the build phase.
    ref.listen(vaultSessionProvider, (prev, next) {
      if (next == null) _closeOnLock();
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
                if (!_isLoading && _error == null && _controller != null)
                  _HeaderIconButton(
                    icon: Icons.fullscreen,
                    tooltip: 'Tela cheia',
                    onPressed: _openFullscreen,
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

    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();

    // Video player with basic controls overlay.
    return ClipRRect(
      borderRadius: isMobile
          ? BorderRadius.zero
          : const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Tappable video area — toggles play/pause.
            GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            ),

            // Center play/pause indicator (visible when paused).
            if (!c.value.isPlaying)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),

            // Bottom controls bar.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _VideoControlsBar(
                controller: c,
                onPlayPause: _togglePlayPause,
                onSeek: _seekTo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Order matters: dispose controller first (tears down the <video>
    // element via video_player's managed teardown), then revoke the blob.
    _disposeController();
    _cleanupBlobUrl();
    super.dispose();
  }
}

// ============================================================
// Bottom controls bar
// ============================================================

class _VideoControlsBar extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  const _VideoControlsBar({
    required this.controller,
    required this.onPlayPause,
    required this.onSeek,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final maxMs = duration.inMilliseconds.toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: BmoColors.accentGreen,
              inactiveTrackColor: Colors.white24,
              thumbColor: BmoColors.accentGreen,
            ),
            child: Slider(
              min: 0,
              max: maxMs > 0 ? maxMs : 1,
              value: position.inMilliseconds
                  .toDouble()
                  .clamp(0, maxMs > 0 ? maxMs : 1),
              onChanged: onSeek,
            ),
          ),

          // Play/pause + time labels
          Row(
            children: [
              // Play/pause button
              InkWell(
                onTap: onPlayPause,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Time display
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),

              const Spacer(),

              // Buffering indicator
              if (value.isBuffering)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Fullscreen overlay (Stack-based, same pattern as image viewer)
// ============================================================

class _VideoFullscreenOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final String fileName;
  final Duration startPosition;
  final bool wasPlaying;

  const _VideoFullscreenOverlay({
    required this.controller,
    required this.fileName,
    required this.startPosition,
    required this.wasPlaying,
  });

  @override
  State<_VideoFullscreenOverlay> createState() =>
      _VideoFullscreenOverlayState();
}

class _VideoFullscreenOverlayState extends State<_VideoFullscreenOverlay> {
  bool _controlsVisible = true;
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;

    // Seek to the position from the inline player.
    if (_controller.value.isInitialized &&
        widget.startPosition != Duration.zero) {
      _controller.seekTo(widget.startPosition);
    }

    // Resume playback if it was playing before.
    if (widget.wasPlaying) {
      _controller.play();
    }

    // Listen for state changes to rebuild controls.
    _controller.addListener(_onUpdate);

    // Auto-hide controls after 3 seconds of inactivity.
    _resetHideTimer();
  }

  void _onUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  void _resetHideTimer() {
    _controlsVisible = true;
    // The auto-hide is handled on each tap — no complex timer needed.
    setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _seekTo(double value) {
    _controller.seekTo(Duration(milliseconds: value.round()));
  }

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    // Don't dispose the controller — it's owned by the parent viewer.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final isInitialized = value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video filling the screen.
            Positioned.fill(
              child: isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                          color: BmoColors.accentGreen),
                    ),
            ),

            // Center play/pause (visible when paused or controls hidden).
            if (isInitialized && (!value.isPlaying || !_controlsVisible))
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
              ),

            // Top bar with file name + close.
            if (_controlsVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.only(
                    top: 48,
                    bottom: 12,
                    left: 16,
                    right: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom controls bar.
            if (_controlsVisible && isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _VideoControlsBar(
                  controller: _controller,
                  onPlayPause: _togglePlayPause,
                  onSeek: _seekTo,
                ),
              ),
          ],
        ),
      ),
    );
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
