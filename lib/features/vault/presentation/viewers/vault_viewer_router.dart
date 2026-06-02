/// Viewer routing for vault items — dispatches to the appropriate viewer
/// based on MIME type.
///
/// Tap on a file item → [openVaultItemViewer] checks the MIME type and opens
/// the right modal viewer. The ⋮ menu (download/delete) is NOT affected —
/// it continues to work independently.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/vault_models.dart';
import '../../data/vault_repository.dart';
import '../../providers/vault_providers.dart';
import 'vault_viewer_image.dart';
import 'vault_viewer_pdf.dart';
import 'vault_viewer_text.dart';
import 'vault_viewer_video.dart';

// ---------------------------------------------------------------------------
// Size thresholds
// ---------------------------------------------------------------------------

/// Files above this size show a warning before attempting in-app preview
/// (image, text, PDF). Above this, the user gets a warning + fallback to
/// download instead of automatic preview.
const kPreviewSizeWarning = 50 * 1024 * 1024; // 50 MiB

/// Videos above this size show a confirmation dialog before loading into
/// memory. Below this threshold, they open directly.
const kVideoLargeWarningThreshold = 1 * 1024 * 1024 * 1024; // 1 GiB

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Opens the appropriate in-app viewer for [item] based on its MIME type.
///
/// Called when the user taps a file item (NOT from the ⋮ menu). The viewer
/// modal fetches and decrypts the file content via [repo], displays it, and
/// cleans up (revokes blob URLs, discards plaintext) on close.
///
/// [session] provides the vaultId, DEK, and decrypted name.
/// [ref] is used to read [vaultRepositoryProvider].
void openVaultItemViewer(
  BuildContext context, {
  required VaultItemDecrypted item,
  required VaultSession session,
  required WidgetRef ref,
  VoidCallback? onDownload,
}) {
  final mime = item.mimeType.toLowerCase();
  final repo = ref.read(vaultRepositoryProvider);
  final isMobile = MediaQuery.of(context).size.width < 600;

  if (mime.startsWith('image/')) {
    _checkSizeThenOpen(
      context,
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
      threshold: kPreviewSizeWarning,
      typeLabel: 'imagem',
      onDownload: onDownload,
      builder: () => VaultImageViewer(
        item: item,
        session: session,
        repo: repo,
        isMobile: isMobile,
      ),
    );
  } else if (mime.startsWith('text/') ||
      mime == 'application/json' ||
      mime == 'application/xml' ||
      mime == 'text/csv') {
    _checkSizeThenOpen(
      context,
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
      threshold: kPreviewSizeWarning,
      typeLabel: 'texto',
      onDownload: onDownload,
      builder: () => VaultTextViewer(
        item: item,
        session: session,
        repo: repo,
        isMobile: isMobile,
      ),
    );
  } else if (mime == 'application/pdf') {
    _checkSizeThenOpen(
      context,
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
      threshold: kPreviewSizeWarning,
      typeLabel: 'PDF',
      onDownload: onDownload,
      builder: () => VaultPdfViewer(
        item: item,
        session: session,
        repo: repo,
        isMobile: isMobile,
      ),
    );
  } else if (mime.startsWith('video/')) {
    _checkVideoSizeThenOpen(
      context,
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
      onDownload: onDownload,
    );
  } else {
    _showUnsupportedType(context, item: item, onDownload: onDownload);
  }
}

// ---------------------------------------------------------------------------
// Size checks
// ---------------------------------------------------------------------------

void _checkSizeThenOpen(
  BuildContext context, {
  required VaultItemDecrypted item,
  required VaultSession session,
  required VaultRepository repo,
  required bool isMobile,
  required int threshold,
  required String typeLabel,
  VoidCallback? onDownload,
  required Widget Function() builder,
}) {
  if (item.originalSize > threshold) {
    _showTooLargeDialog(
      context,
      item: item,
      typeLabel: typeLabel,
      sizeBytes: item.originalSize,
      onDownload: onDownload,
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => builder(),
  );
}

void _checkVideoSizeThenOpen(
  BuildContext context, {
  required VaultItemDecrypted item,
  required VaultSession session,
  required VaultRepository repo,
  required bool isMobile,
  VoidCallback? onDownload,
}) {
  if (item.originalSize > kVideoLargeWarningThreshold) {
    _showLargeVideoDialog(
      context,
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
      onDownload: onDownload,
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => VaultVideoViewer(
      item: item,
      session: session,
      repo: repo,
      isMobile: isMobile,
    ),
  );
}

// ============================================================
// Unsupported type dialog
// ============================================================

void _showUnsupportedType(
  BuildContext context, {
  required VaultItemDecrypted item,
  VoidCallback? onDownload,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      title: const Text(
        'Pré-visualização indisponível',
        style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
      ),
      content: Text(
        "O tipo de arquivo '${item.mimeType}'\n"
        'não pode ser visualizado no app.\n'
        'Use a opção Baixar para abrir\n'
        'com o programa apropriado.',
        style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: BmoColors.accentGreen),
          onPressed: () {
            Navigator.of(ctx).pop();
            onDownload?.call();
          },
          child: const Text('Baixar',
              style: TextStyle(color: BmoColors.screenBg)),
        ),
      ],
    ),
  );
}

// ============================================================
// Too-large warning dialogs
// ============================================================

void _showTooLargeDialog(
  BuildContext context, {
  required VaultItemDecrypted item,
  required String typeLabel,
  required int sizeBytes,
  VoidCallback? onDownload,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: BmoColors.accentYellow, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Arquivo muito grande',
            style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
          ),
        ],
      ),
      content: Text(
        'Este arquivo de ${_formatSize(sizeBytes)} é '
        'grande demais\n'
        'para pré-visualização de $typeLabel no app.\n\n'
        'Use a opção Baixar para abri-lo com\n'
        'o programa apropriado.',
        style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: BmoColors.accentGreen),
          onPressed: () {
            Navigator.of(ctx).pop();
            onDownload?.call();
          },
          child: const Text('Baixar',
              style: TextStyle(color: BmoColors.screenBg)),
        ),
      ],
    ),
  );
}

void _showLargeVideoDialog(
  BuildContext context, {
  required VaultItemDecrypted item,
  required VaultSession session,
  required VaultRepository repo,
  required bool isMobile,
  VoidCallback? onDownload,
}) {
  final sizeLabel = _formatSize(item.originalSize);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: BmoColors.accentYellow, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Vídeo muito grande',
            style: TextStyle(color: BmoColors.textPrimary, fontSize: 14),
          ),
        ],
      ),
      content: Text(
        'Este vídeo tem ~$sizeLabel.\n\n'
        'Reproduzir no app carrega ele inteiro na\n'
        'memória e pode travar a aba dependendo\n'
        'da memória disponível.\n\n'
        '⚠️ Se a aba travar, o cofre será\n'
        're-travado (a sessão se perde).\n\n'
        'O ideal é Baixar e abrir no seu player.',
        style: const TextStyle(color: BmoColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: BmoColors.accentGreen),
          onPressed: () {
            Navigator.of(ctx).pop();
            onDownload?.call();
          },
          child: const Text('Baixar',
              style: TextStyle(color: BmoColors.screenBg)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: BmoColors.accentYellow),
          onPressed: () {
            Navigator.of(ctx).pop();
            // Open video viewer directly — bypass the size check this time.
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) => VaultVideoViewer(
                item: item,
                session: session,
                repo: repo,
                isMobile: isMobile,
              ),
            );
          },
          child: const Text('Tentar reproduzir',
              style: TextStyle(color: BmoColors.screenBg)),
        ),
      ],
    ),
  );
}

// ============================================================
// Helpers
// ============================================================

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) {
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
}
