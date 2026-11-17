import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';
import '../data/bmo_rich_block.dart';

/// Card do bloco rico `briefing`.
///
/// Payload `{"sections": [{"key","title","lines": [...]}, ...]}` na ordem do
/// contrato. O texto do turno já traz a versão escrita; o card só detalha.
/// `speech` não é renderizado (como nos outros blocos).
///
/// O bloco é imutável e não tem endpoint REST próprio: não há o que
/// re-sincronizar — o histórico/stream já trazem o payload.
class BmoRichBriefingCard extends StatelessWidget {
  final BmoRichBlock block;

  const BmoRichBriefingCard({super.key, required this.block});

  List<_BriefingSection> get _sections {
    final raw = block.payload['sections'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          _BriefingSection.fromJson(Map<String, dynamic>.from(item)),
    ].where((section) => section.lines.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _sections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: BmoColors.accentYellow.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.wb_sunny_outlined,
                  size: 16,
                  color: BmoColors.accentYellow,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bom dia',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: BmoColors.accentYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            for (final section in sections) ...[
              const SizedBox(height: 10),
              Text(
                section.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: BmoColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final line in section.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BmoColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BriefingSection {
  final String key;
  final String title;
  final List<String> lines;

  const _BriefingSection({
    required this.key,
    required this.title,
    required this.lines,
  });

  factory _BriefingSection.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return _BriefingSection(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lines: [
        if (rawLines is List)
          for (final line in rawLines) line.toString(),
      ],
    );
  }
}
