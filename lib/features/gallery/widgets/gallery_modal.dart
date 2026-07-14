import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/bmo_theme.dart';
import '../data/image_model.dart';
import '../providers/images_provider.dart';
import 'gallery_image_detail.dart';

const _kMobileBreakpoint = 600.0;

void showGalleryModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _GalleryModal(),
  );
}

class _GalleryModal extends ConsumerStatefulWidget {
  const _GalleryModal();

  @override
  ConsumerState<_GalleryModal> createState() => _GalleryModalState();
}

class _GalleryModalState extends ConsumerState<_GalleryModal> {
  @override
  void initState() {
    super.initState();
    // Re-fetch on every open so new images appear without re-opening.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesProvider.notifier).refresh();
    });
  }

  Future<void> _confirmAndDelete(GalleryImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BmoColors.screenBgElevated,
        title: const Text('Apagar imagem?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(imagesProvider.notifier).deleteImage(image.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao apagar: $e')),
        );
      }
    }
  }

  void _openDetail(GalleryImage image) {
    showDialog(
      context: context,
      builder: (_) => GalleryImageDetail(
        image: image,
        onDelete: () => _confirmAndDelete(image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;
    final imagesAsync = ref.watch(imagesProvider);

    return Dialog(
      backgroundColor: BmoColors.screenBgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BmoColors.bodyGreen, width: 2),
      ),
      insetPadding: isMobile
          ? const EdgeInsets.all(8)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : 800,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _GalleryHeader(
              onClose: () => Navigator.of(context).pop(),
            ),
            // Content
            Flexible(
              child: imagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _GalleryErrorState(
                  error: e,
                  onRetry: () =>
                      ref.read(imagesProvider.notifier).refresh(),
                ),
                data: (images) {
                  if (images.isEmpty) {
                    return const _GalleryEmptyState();
                  }
                  return RefreshIndicator(
                    color: BmoColors.accentGreen,
                    onRefresh: () =>
                        ref.read(imagesProvider.notifier).refresh(),
                    child: _ImageGrid(
                      images: images,
                      isMobile: isMobile,
                      onTap: _openDetail,
                      onDelete: _confirmAndDelete,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Header
// ============================================================

class _GalleryHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _GalleryHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Text(
            'Galeria',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: BmoColors.textSecondary),
            tooltip: 'Fechar',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Image grid
// ============================================================

class _ImageGrid extends StatelessWidget {
  final List<GalleryImage> images;
  final bool isMobile;
  final void Function(GalleryImage) onTap;
  final Future<void> Function(GalleryImage) onDelete;

  const _ImageGrid({
    required this.images,
    required this.isMobile,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (_, index) => _ImageThumbnail(
        image: images[index],
        onTap: () => onTap(images[index]),
        onDelete: () => onDelete(images[index]),
      ),
    );
  }
}

// ============================================================
// Thumbnail
// ============================================================

class _ImageThumbnail extends StatelessWidget {
  final GalleryImage image;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageThumbnail({
    required this.image,
    required this.onTap,
    required this.onDelete,
  });

  String get _imageUrl =>
      '${Env.bmoServerUrl}/api/v1/images/${image.id}/file';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: BmoColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or placeholder
            if (image.isDone)
              Image.network(
                _imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return _buildLoadingPlaceholder(progress);
                },
                errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
              )
            else if (image.isGenerating)
              _buildGeneratingPlaceholder()
            else
              _buildErrorPlaceholder(),

            // Popup menu
            Positioned(
              top: 2,
              right: 2,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 16,
                  color: BmoColors.textPrimary,
                ),
                color: BmoColors.screenBgElevated,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Apagar'),
                  ),
                ],
              ),
            ),

            // Mode badge
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: BmoColors.screenBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  image.mode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: BmoColors.textSecondary,
                        fontSize: 10,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ImageChunkEvent progress) {
    final total = progress.expectedTotalBytes;
    final loaded = progress.cumulativeBytesLoaded;
    final fraction = total != null && total > 0 ? loaded / total : null;
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: fraction,
          strokeWidth: 2,
          color: BmoColors.accentGreen,
        ),
      ),
    );
  }

  Widget _buildGeneratingPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: BmoColors.accentGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gerando...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: BmoColors.accentYellow,
      ),
    );
  }
}

// ============================================================
// Empty state
// ============================================================

class _GalleryEmptyState extends StatelessWidget {
  const _GalleryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: BmoColors.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'Nenhuma imagem ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: BmoColors.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Gere imagens pelo chat para vê-las aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: BmoColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Error state
// ============================================================

class _GalleryErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _GalleryErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'Falha ao carregar',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: BmoColors.textMuted,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
