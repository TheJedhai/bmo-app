import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../gallery/data/image_model.dart';
import '../../gallery/providers/images_provider.dart';

/// Card da galeria — span 2×1.
///
/// Mostra a thumbnail da imagem mais recente como fundo do card com
/// overlay escuro gradiente. Se não houver imagens, mostra ícone
/// image_outlined centralizado. Toque abre a galeria (showGalleryModal),
/// preservando o comportamento da Home antiga.
class GalleryCard extends ConsumerWidget {
  const GalleryCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(imagesProvider);

    return imagesAsync.when(
      loading: () {
        debugPrint('[GalleryCard] state=loading');
        return const _LoadingState();
      },
      error: (e, st) {
        debugPrint('[GalleryCard] state=error — $e\n$st');
        return const _ErrorState();
      },
      data: (images) {
        debugPrint('[GalleryCard] state=data — ${images.length} imagens');
        return _GalleryContent(images: images);
      },
    );
  }
}

class _GalleryContent extends ConsumerWidget {
  const _GalleryContent({required this.images});

  final List<GalleryImage> images;

  GalleryImage? get _mostRecent {
    if (images.isEmpty) return null;
    final sorted = List<GalleryImage>.from(images);
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate); // descending
    });
    // Pega a primeira imagem com status "done".
    return sorted.cast<GalleryImage?>().firstWhere(
          (img) => img!.isDone,
          orElse: () => sorted.first,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = _mostRecent;

    if (recent == null) {
      // Nenhuma imagem — placeholder com ícone.
      // O DashCard já provê o InkWell + onTap que chama showGalleryModal.
      return const Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: BmoColors.textMuted,
        ),
      );
    }

    // Thumbnail como fundo com overlay gradiente escuro,
    // fetched via ImagesClient (que injeta X-User-Id).
    final bytesAsync = ref.watch(imageBytesProvider(recent.id));

    // O DashCard já provê o InkWell + onTap que chama showGalleryModal.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          bytesAsync.when(
            loading: () => const Center(
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: BmoColors.textMuted,
              ),
            ),
            error: (e, st) {
              debugPrint('[GalleryCard] imageBytesProvider(${recent.id}) error — $e\n$st');
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: BmoColors.textMuted,
                ),
              );
            },
            data: (bytes) => Image.memory(
              bytes,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay gradiente escuro para legibilidade.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 48,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xCC1E1F23),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_outlined, size: 40, color: BmoColors.textMuted),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 40,
        color: BmoColors.textMuted,
      ),
    );
  }
}
