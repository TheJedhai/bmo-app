/// In-app image viewer for vault items.
///
/// Fetches the full image via [VaultRepository.downloadItem], displays it
/// with [Image.memory], and offers a fullscreen overlay with [InteractiveViewer]
/// for zoom/pan.
///
/// ## Security
/// - Decrypted bytes live only while the viewer is open; discarded on close.
/// - No DEK, plaintext, or blob URL in log/storage.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_client.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';

// ============================================================
// Viewer dialog (modal, mirrors ArticleDetailModal pattern)
// ============================================================

class VaultImageViewer extends ConsumerStatefulWidget {
  final VaultItemDecrypted item;
  final VaultSession session;
  final VaultRepository repo;
  final bool isMobile;

  /// Called when the user taps "Baixar" after a memory error.
  final VoidCallback? onDownload;

  const VaultImageViewer({
    super.key,
    required this.item,
    required this.session,
    required this.repo,
    required this.isMobile,
    this.onDownload,
  });

  @override
  ConsumerState<VaultImageViewer> createState() => _VaultImageViewerState();
}

class _VaultImageViewerState extends ConsumerState<VaultImageViewer> {
  Uint8List? _bytes;
  bool _isLoading = true;
  String? _error;
  bool _isMemoryError = false;
  bool _isFullscreenOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _isMemoryError = false;
    try {
      final bytes = await widget.repo.downloadItem(
        widget.session.vaultId,
        widget.session.dek,
        widget.item.id,
        onProgress: (received, total) {
          // Progress is shown in the loading state — not needed separately
          // for images since they're typically small.
        },
      );
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  void _openFullscreen() {
    if (_bytes == null) return;
    _isFullscreenOpen = true;
    Navigator.of(context)
        .push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _ImageFullscreenOverlay(
          bytes: _bytes!,
          fileName: widget.item.fileName,
        ),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
      ),
    )
        .then((_) {
      if (mounted) _isFullscreenOpen = false;
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

  @override
  Widget build(BuildContext context) {
    // Close this viewer when the vault locks (session → null).
    // Must be called from build, not initState — Riverpod requires
    // ref.listen to be registered during the build phase.
    ref.listen(vaultSessionProvider, (prev, next) {
      if (next == null) _closeOnLock();
    });

    final isMobile = widget.isMobile;

    return Dialog(
      backgroundColor: BmoColors.screenBg,
      shape: isMobile
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
      insetPadding: isMobile
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 900,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _ViewerHeader(
              title: widget.item.fileName,
              actions: [
                if (_bytes != null)
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
              child: _buildContent(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: BmoColors.accentGreen),
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
                  maxLines: 3),
              const SizedBox(height: 12),
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

    if (_bytes == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: isMobile
          ? BorderRadius.zero
          : const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Text('Não foi possível exibir a imagem.',
              style: TextStyle(
                  fontFamily: 'Inter',
                  color: BmoColors.textSecondary)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Discard decrypted bytes — nothing persists.
    _bytes = null;
    super.dispose();
  }
}

// ============================================================
// Fullscreen overlay (Stack-based, no platform view issues)
// ============================================================

class _ImageFullscreenOverlay extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const _ImageFullscreenOverlay({
    required this.bytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image with zoom/pan
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 8.0,
              child: Center(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Não foi possível exibir a imagem.',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
            ),
          ),

          // Top bar with file name + close
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
                      fileName,
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
        ],
      ),
    );
  }
}

// ============================================================
// Shared viewer header
// ============================================================

class _ViewerHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const _ViewerHeader({
    required this.title,
    this.actions = const [],
  });

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

/// A small icon button for the viewer header toolbar.
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
          child:
              Icon(icon, size: 20, color: BmoColors.textSecondary),
        ),
      ),
    );
  }
}
