import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/bmo_rich_block.dart';

/// Renders a rich-content block of type "image".
///
/// Fetches the image from `GET {bmoServerUrl}/api/v1/images/{imageId}/file`.
///
/// States:
/// - **Loading**: "Gerando imagem..." placeholder with a determinate or
///   indeterminate [CircularProgressIndicator].
/// - **Success**: the image itself, constrained to bubble width with rounded
///   corners.
/// - **Error / 404**: same placeholder as loading (static; real-time updates
///   come in a later slice).
class BmoRichImageCard extends StatelessWidget {
  final BmoRichBlock block;

  const BmoRichImageCard({super.key, required this.block});

  String get _imageUrl {
    final imageId = block.payload['image_id'];
    if (imageId == null) return '';
    return '${Env.bmoServerUrl}/api/v1/images/$imageId/file';
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl;
    if (url.isEmpty) return _buildPlaceholder(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
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
