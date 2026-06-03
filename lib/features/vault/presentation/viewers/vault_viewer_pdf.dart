/// In-app PDF viewer for vault items.
///
/// Uses the browser's native PDF viewer via an iframe + blob URL.
/// **Zero additional dependencies** — Chrome's built-in PDF viewer handles
/// rendering, zoom, search, page navigation, and printing.
///
/// ## Why iframe instead of pdfx?
/// pdfx adds ~500 KB (PDF.js + photo_view + utility deps) for functionality
/// the browser already provides natively. The iframe approach:
/// - Zero dependencies
/// - Native Chrome PDF viewer (zoom, search, page nav, print, rotate)
/// - Same user experience as opening a PDF in Chrome
/// - No z-order issues (the iframe is the only platform view in the dialog,
///   and the close button is in a Flutter header above it)
///
/// ## Memory / platform view lifecycle
/// Same strategy as the video viewer: the platform view factory closes over
/// only a string key (viewType), looking up the actual iframe element from a
/// global map.  On dispose the entry is removed → the factory (stuck in the
/// registry forever) no longer reaches the element → GC collects the buffer.
///
/// ## Security
/// - Decrypted PDF bytes → blob URL → iframe. Blob URL is revoked on close.
/// - No plaintext in log/storage.
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
// Global iframe element registry
// ---------------------------------------------------------------------------

/// Maps viewType → live `<iframe>` element so the platform view factory
/// can look up the element without capturing it in a closure.
final _iframeElements = <String, html.IFrameElement>{};

int _nextPdfViewId = 0;

/// Creates a unique viewType for a single viewer instance.
String _nextPdfViewType() => 'vault-pdf-${_nextPdfViewId++}';

/// Platform view factory.  Captures only [viewType] (a short string), NOT
/// the iframe element.
html.IFrameElement _pdfPlatformFactory(int viewId, String viewType) {
  return _iframeElements[viewType]!;
}

// ============================================================
// Viewer dialog
// ============================================================

class VaultPdfViewer extends ConsumerStatefulWidget {
  final VaultItemDecrypted item;
  final VaultSession session;
  final VaultRepository repo;
  final bool isMobile;

  /// Called when the user taps "Baixar" after a memory error.
  final VoidCallback? onDownload;

  const VaultPdfViewer({
    super.key,
    required this.item,
    required this.session,
    required this.repo,
    required this.isMobile,
    this.onDownload,
  });

  @override
  ConsumerState<VaultPdfViewer> createState() => _VaultPdfViewerState();
}

class _VaultPdfViewerState extends ConsumerState<VaultPdfViewer> {
  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  bool _isMemoryError = false;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Clean up state from a previous attempt.
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

      // Create blob URL for the iframe
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrl(blob);

      if (!mounted) {
        html.Url.revokeObjectUrl(url);
        return;
      }
      setState(() {
        _blobUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  void _cleanupBlobUrl() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
      _blobUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(vaultSessionProvider, (prev, next) {
      if (next == null) Navigator.of(context).pop();
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
          : const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _ViewerHeader(
              title: widget.item.fileName,
              actions: [
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: BmoColors.accentGreen),
            if (_progress > 0) ...[
              const SizedBox(height: 12),
              Text('Decifrando… ${(_progress * 100).toStringAsFixed(0)}%',
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

    // Rebuild iframe when blob URL changes (key ensures a fresh widget).
    return _PdfIframe(
      key: ValueKey(_blobUrl),
      blobUrl: _blobUrl!,
    );
  }

  @override
  void dispose() {
    _cleanupBlobUrl();
    super.dispose();
  }
}

// ============================================================
// PDF iframe (browser's native PDF viewer)
// ============================================================

class _PdfIframe extends StatefulWidget {
  final String blobUrl;

  const _PdfIframe({super.key, required this.blobUrl});

  @override
  State<_PdfIframe> createState() => _PdfIframeState();
}

class _PdfIframeState extends State<_PdfIframe> {
  late final html.IFrameElement _iframe;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = _nextPdfViewType();
    _iframe = html.IFrameElement()
      ..src = widget.blobUrl
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none';

    // Store in global registry so the factory can look it up without
    // capturing the element directly.
    _iframeElements[_viewType] = _iframe;

    // Register factory.  The closure captures only [_viewType], NOT
    // [_iframe] — see _pdfPlatformFactory.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _pdfPlatformFactory(viewId, _viewType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }

  @override
  void dispose() {
    // Release the iframe's reference to the blob (so Chrome frees the
    // decoded PDF buffer) and remove from the global registry so the
    // factory (still held by platformViewRegistry) can no longer reach
    // this element → GC collects it.
    try {
      _iframe.src = '';
      if (_iframe.parentNode != null) {
        _iframe.remove();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
    _iframeElements.remove(_viewType);
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
