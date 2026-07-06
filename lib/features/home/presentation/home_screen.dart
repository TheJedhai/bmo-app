import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../gallery/widgets/gallery_modal.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BMO greeting / icon
            Icon(
              Icons.face,
              size: isMobile ? 64 : 80,
              color: BmoColors.accentGreen.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'BMO',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: BmoColors.accentGreen,
              ),
            ),
            const SizedBox(height: 32),
            // Gallery button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BmoColors.accentGreen,
                foregroundColor: const Color(0xFF0F1115),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => showGalleryModal(context),
              icon: const Icon(Icons.image_outlined, size: 20),
              label: Text(
                'Galeria de Imagens',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0F1115),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
