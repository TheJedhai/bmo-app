import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../gallery/data/image_model.dart';
import '../../gallery/providers/images_provider.dart';

/// Card da galeria.
///
/// Carrossel das últimas 5 imagens concluídas com auto-avanço de 5s,
/// setas laterais (hover desktop / sempre mobile) e dots indicadores.
/// Toque na imagem via DashCard onTap (showGalleryModal).
class GalleryCard extends ConsumerStatefulWidget {
  const GalleryCard({super.key, required this.accent});

  final Color accent;

  @override
  ConsumerState<GalleryCard> createState() => _GalleryCardState();
}

class _GalleryCardState extends ConsumerState<GalleryCard> {
  late final PageController _pageController = PageController();

  int _currentIndex = 0;
  Timer? _autoAdvanceTimer;
  bool _isHovered = false;
  Set<int> _lastKnownIds = {};

  /// Últimas 5 imagens concluídas, da mais recente para a mais antiga.
  List<GalleryImage> _getCompletedImages(List<GalleryImage> images) {
    if (images.isEmpty) return const [];
    final sorted = List<GalleryImage>.from(images);
    sorted.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(1970);
      final bDate = b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return sorted.where((img) => img.isDone).take(5).toList();
  }

  // ------------------------------------------------------------------
  // Timer
  // ------------------------------------------------------------------

  void _startTimer() {
    _cancelTimer();
    if (!mounted) return;
    _autoAdvanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || !_pageController.hasClients) return;
        final count = _lastKnownIds.length;
        if (count <= 1) return;
        final nextPage = (_currentIndex + 1) % count;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _cancelTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  // ------------------------------------------------------------------
  // Navegação manual (setas / dots)
  // ------------------------------------------------------------------

  void _goToPage(int index) {
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _startTimer(); // reseta o timer a cada troca de página
  }

  // ------------------------------------------------------------------
  // Sincronização com a lista de imagens
  // ------------------------------------------------------------------

  void _syncWithImages(List<GalleryImage> completed) {
    final newIds = completed.map((i) => i.id).toSet();
    if (newIds.length == _lastKnownIds.length &&
        newIds.containsAll(_lastKnownIds)) {
      return;
    }
    _lastKnownIds = newIds;

    if (completed.length <= 1) {
      _cancelTimer();
      if (_currentIndex != 0 && mounted) {
        setState(() => _currentIndex = 0);
      }
      return;
    }

    // Clampa índice se a lista encolheu
    if (_currentIndex >= completed.length) {
      setState(() => _currentIndex = 0);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }

    _startTimer();
  }

  // ------------------------------------------------------------------
  // Construção visual de cada página do carrossel
  // ------------------------------------------------------------------

  Widget _buildImagePage(GalleryImage img) {
    final bytesAsync = ref.watch(imageBytesProvider(img.id));

    return Stack(
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
              '[GalleryCard] imageBytesProvider(${img.id}) error — $e\n$st',
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
        if (img.prompt != null && img.prompt!.isNotEmpty)
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Text(
              img.prompt!,
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
    );
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  void dispose() {
    _cancelTimer();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(imagesProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

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
        final completed = _getCompletedImages(images);

        // Sincroniza timer em post-frame para evitar setState durante build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncWithImages(completed);
        });

        if (completed.isEmpty) {
          return const Center(
            child: Icon(
              Icons.image_outlined,
              size: 40,
              color: BmoColors.textMuted,
            ),
          );
        }

        final showControls = completed.length > 1;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasFiniteHeight = constraints.maxHeight.isFinite;

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasFiniteHeight
                    ? SizedBox.expand(
                        child: _buildCarousel(completed, showControls, isMobile),
                      )
                    : SizedBox(
                        height: 160,
                        child: _buildCarousel(completed, showControls, isMobile),
                      ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCarousel(
    List<GalleryImage> images,
    bool showControls,
    bool isMobile,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // --- PageView com imagens ---
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: images.length,
          itemBuilder: (context, index) => _buildImagePage(images[index]),
        ),

        // --- Seta esquerda ---
        if (showControls && (isMobile || _isHovered))
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () =>
                  _goToPage((_currentIndex - 1 + images.length) % images.length),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),

        // --- Seta direita ---
        if (showControls && (isMobile || _isHovered))
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () =>
                  _goToPage((_currentIndex + 1) % images.length),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                  size: 28,
                ),
              ),
            ),
          ),

        // --- Dots indicadores ---
        if (showControls)
          Positioned(
            bottom: 58,
            left: 0,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // absorve o tap para não propagar ao DashCard
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final isActive = i == _currentIndex;
                  return GestureDetector(
                    onTap: () => _goToPage(i),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? widget.accent
                            : BmoColors.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}

// ====================================================================
// Estados de loading / erro (inalterados)
// ====================================================================

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
