import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../gallery/data/image_model.dart';
import '../../gallery/providers/images_provider.dart';

/// Card da galeria.
///
/// Mostra a thumbnail da imagem mais recente preenchendo todo o card com
/// overlay gradiente escuro no rodapé e título da imagem em branco bold.
/// Toque via DashCard onTap (showGalleryModal).
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
      return bDate.compareTo(aDate);
    });
    return sorted.cast<GalleryImage?>().firstWhere(
          (img) => img!.isDone,
          orElse: () => sorted.first,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = _mostRecent;

    if (recent == null) {
      return const Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: BmoColors.textMuted,
        ),
      );
    }

    final bytesAsync = ref.watch(imageBytesProvider(recent.id));

    // LayoutBuilder com fallback porque o DashCard usa Column(mainAxisSize.min),
    // que passa altura infinita para os filhos. Com altura infinita,
    // StackFit.expand quebra. Usamos 160px de fallback: 220px do spec
    // menos ~60px de chrome do DashCard (header + padding).
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 160.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: imageHeight,
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
                    debugPrint(
                      '[GalleryCard] imageBytesProvider(${recent.id}) error — $e\n$st',
                    );
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
                // Overlay gradiente escuro no rodapé
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 56,
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
                // Título da imagem (prompt) sobre o overlay
                if (recent.prompt != null && recent.prompt!.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      recent.prompt!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
