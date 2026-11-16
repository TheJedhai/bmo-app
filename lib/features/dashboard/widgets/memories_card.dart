import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bmo_theme.dart';
import '../../rich_blocks/widgets/bmo_clamped_text.dart';
import '../../memories/providers/memories_provider.dart';
import '../../memories/widgets/memory_scope_chip.dart';

/// Card de atalho para Memórias: contagem e as duas últimas memórias, com
/// chip de escopo. Toque via DashCard onTap → `/memorias`.
class MemoriesCard extends ConsumerWidget {
  const MemoriesCard({super.key, required this.accent});

  final Color accent;

  static const _kPreviewCount = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final memoriesAsync = ref.watch(memoriesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: memoriesAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: BmoColors.accentGreen,
              ),
            ),
          ),
        ),
        error: (_, _) => Text(
          'memórias indisponíveis',
          style: theme.textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
        ),
        data: (memories) {
          if (memories.isEmpty) {
            return Text(
              'nenhuma memória ainda',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: BmoColors.textMuted),
            );
          }

          final preview = memories.take(_kPreviewCount).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '${memories.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    memories.length == 1 ? 'memória' : 'memórias',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: BmoColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final memory in preview)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        memory.source == 'agent'
                            ? Icons.smart_toy_outlined
                            : Icons.person_outline,
                        size: 13,
                        color: BmoColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: BmoClampedText(
                          memory.content,
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: BmoColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      MemoryScopeChip(personal: memory.isPersonal),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
