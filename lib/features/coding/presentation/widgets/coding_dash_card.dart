import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/bmo_theme.dart';
import '../../data/coding_providers.dart';

/// Card da dashboard para a feature Coding.
///
/// Mostra quantidade de projetos e nome do projeto mais recente.
class CodingDashCard extends ConsumerWidget {
  const CodingDashCard({super.key, required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const _EmptyContent(),
      data: (projects) {
        if (projects.isEmpty) return const _EmptyContent();

        final count = projects.length;
        final latest = projects.first;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contagem de projetos
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 34,
                      color: accent,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.40),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      count == 1 ? 'projeto' : 'projetos',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: BmoColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Projeto mais recente
              const Text(
                'Mais recente',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: BmoColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                latest.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: BmoColors.textPrimary,
                ),
              ),
              Text(
                latest.primaryPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: BmoColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          'Nenhum projeto ainda',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: BmoColors.textMuted,
          ),
        ),
      ),
    );
  }
}
