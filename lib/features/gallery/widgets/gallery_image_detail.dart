import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/image_model.dart';

/// Full-screen-ish detail view for a single gallery image.
///
/// Shows the image at full resolution via /images/{id}/file, with optional
/// metadata (prompt, model, strength) below.  Includes a delete action.
class GalleryImageDetail extends StatelessWidget {
  final GalleryImage image;
  final VoidCallback onDelete;

  const GalleryImageDetail({
    super.key,
    required this.image,
    required this.onDelete,
  });

  String get _imageUrl =>
      '${Env.bmoServerUrl}/api/v1/images/${image.id}/file';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hasMeta =
        image.prompt != null || image.model != null || image.strength != null;

    return Dialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 900,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    image.mode == 'img2img' ? 'img2img' : 'txt2img',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: BmoColors.accentGreen,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: BmoColors.textSecondary, size: 20),
                    tooltip: 'Apagar',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: BmoColors.textSecondary, size: 20),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Image
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: image.isDone
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return _buildLoading(progress);
                          },
                          errorBuilder: (_, _, _) => _buildError(),
                        ),
                      )
                    : _buildGenerating(),
              ),
            ),
            // Metadata
            if (hasMeta)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  color: BmoColors.screenBg.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image.prompt != null && image.prompt!.isNotEmpty) ...[
                      _MetaRow(
                        label: 'Prompt',
                        value: image.prompt!,
                        maxLines: 4,
                      ),
                    ],
                    if (image.model != null && image.model!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _MetaRow(label: 'Modelo', value: image.model!),
                    ],
                    if (image.strength != null) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                        label: 'Strength',
                        value: image.strength!.toStringAsFixed(2),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(ImageChunkEvent progress) {
    final total = progress.expectedTotalBytes;
    final loaded = progress.cumulativeBytesLoaded;
    final fraction = total != null && total > 0 ? loaded / total : null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 3,
              color: BmoColors.accentGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Carregando imagem...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerating() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: BmoColors.accentGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gerando imagem...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 48, color: BmoColors.accentYellow),
          const SizedBox(height: 12),
          Text(
            'Erro ao carregar imagem',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Metadata row
// ============================================================

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const _MetaRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow:
                maxLines > 1 ? TextOverflow.ellipsis : TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: BmoColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
