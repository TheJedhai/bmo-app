/// In-app PDF viewer for vault items.
///
/// Delegates to the platform's built-in PDF viewer — the browser's via an
/// iframe + blob URL (web), the system's Quick Look sheet (native).
/// **Zero additional rendering deps** — no pdfx/pdfrx (both bundle PDFium,
/// ~4 MB on web) for something the platform already does.
///
/// The platform difference lives behind [createPdfPreview] in
/// core/platform — this file has no platform code.
///
/// ## Resource lifecycle
/// Web: blob URL revoked when this dialog closes (as always).
/// Native: the Quick Look sheet is closed by the SYSTEM, so the handle is
/// handed to the vault screen ([onPreviewOpened]) and the temp file dies
/// with the screen's dispose — see core/platform/pdf_preview.dart.
///
/// ## Security
/// - Decrypted PDF bytes → blob URL → iframe (web) / temp file → Quick
///   Look (native). Released on dialog close (web) or screen dispose
///   (native).
/// - No plaintext in log/storage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/pdf_preview.dart';
import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_client.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';

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

  /// Native only: receives the preview handle once the Quick Look sheet is
  /// up, so the vault screen can dispose it in its own dispose. Web never
  /// calls this — the blob URL dies with this dialog.
  final void Function(PdfPreview preview)? onPreviewOpened;

  const VaultPdfViewer({
    super.key,
    required this.item,
    required this.session,
    required this.repo,
    required this.isMobile,
    this.onDownload,
    this.onPreviewOpened,
  });

  @override
  ConsumerState<VaultPdfViewer> createState() => _VaultPdfViewerState();
}

class _VaultPdfViewerState extends ConsumerState<VaultPdfViewer> {
  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  bool _isMemoryError = false;
  PdfPreview? _preview;
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Clean up state from a previous attempt.
    _cleanupPreview();
    _handedOff = false;
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

      final preview = await createPdfPreview(bytes);
      if (!mounted) {
        preview.dispose();
        return;
      }
      setState(() {
        _preview = preview;
        _isLoading = false;
      });

      if (!preview.isSystemPresented) return; // web: iframe already built.

      // Native: present the Quick Look sheet and hand the handle to the
      // vault screen — the system closes the sheet, so the temp file can
      // only die with the screen's dispose (see core/platform/pdf_preview).
      final ok = await preview.present();
      if (!mounted) {
        // Dialog died during presentation (lock, barrier) — the handle has
        // no owner anymore: release it here. The sheet may have just come
        // up; Quick Look already loaded the preview into its own process,
        // and the OS purges the temp dir anyway. Security first.
        preview.dispose();
        return;
      }
      if (ok) {
        widget.onPreviewOpened?.call(preview);
        _handedOff = true;
        Navigator.of(context).pop();
      } else {
        setState(() {
          _error = 'Não foi possível abrir o visualizador do sistema.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _cleanupPreview();

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

  void _cleanupPreview() {
    final p = _preview;
    _preview = null;
    p?.dispose();
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

    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    return preview.buildContent();
  }

  @override
  void dispose() {
    // Web: the blob URL dies with this dialog. Native: after a successful
    // handoff the screen owns the handle; when the dialog dies before the
    // handoff (lock mid-presentation) the handle is released here.
    final p = _preview;
    if (p != null && !_handedOff) p.dispose();
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
