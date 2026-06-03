/// In-app text viewer for vault items.
///
/// Fetches the full file via [VaultRepository.downloadItem], UTF-8 decodes it,
/// and displays it in a scrollable, selectable text area.
///
/// Handles invalid UTF-8 with a clear error message. Bytes discarded on close.
///
/// ## Security
/// - Decrypted content lives only while the viewer is open.
/// - No plaintext in log/storage.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_client.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';

// ============================================================
// Viewer dialog
// ============================================================

class VaultTextViewer extends ConsumerStatefulWidget {
  final VaultItemDecrypted item;
  final VaultSession session;
  final VaultRepository repo;
  final bool isMobile;

  /// Called when the user taps "Baixar" after a memory error.
  final VoidCallback? onDownload;

  const VaultTextViewer({
    super.key,
    required this.item,
    required this.session,
    required this.repo,
    required this.isMobile,
    this.onDownload,
  });

  @override
  ConsumerState<VaultTextViewer> createState() => _VaultTextViewerState();
}

class _VaultTextViewerState extends ConsumerState<VaultTextViewer> {
  String? _text;
  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  bool _isMemoryError = false;

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
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;

      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        // Try Latin-1 as fallback for non-UTF-8 text
        try {
          text = latin1.decode(bytes);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _error =
                'Não foi possível decodificar o arquivo como texto.\n'
                'O arquivo pode ser binário ou estar em uma\n'
                'codificação não suportada.';
            _isLoading = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _text = text;
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
          : const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 800,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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

    if (_text == null) return const SizedBox.shrink();

    return SelectableText(
      _text!,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: BmoColors.textPrimary,
        height: 1.6,
      ),
      scrollPhysics: const ClampingScrollPhysics(),
    );
  }

  @override
  void dispose() {
    _text = null;
    super.dispose();
  }
}

// ============================================================
// Shared widgets (duplicated per file to keep each viewer self-contained;
// could be extracted later)
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
