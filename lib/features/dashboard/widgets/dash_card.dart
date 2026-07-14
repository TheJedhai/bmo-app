import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';

/// Chassi visual comum de todo widget da dashboard.
///
/// Container com [BmoColors.screenBgElevated], borda 1px accentGreen com
/// alpha 0.25, borderRadius 12, e glow sutil (boxShadow accentGreen alpha
/// ~0.08, blur 12).
///
/// Header opcional: título em PressStart2P tamanho ~10, cor textMuted,
/// uppercase.
///
/// Parâmetro [onTap] opcional: se presente, envolve em InkWell e mostra
/// chevron discreto no header.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    this.title,
    this.onTap,
    required this.child,
  });

  final String? title;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: BmoColors.screenBgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: BmoColors.accentGreen.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: BmoColors.accentGreen.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) _DashCardHeader(title: title!, showChevron: onTap != null),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

class _DashCardHeader extends StatelessWidget {
  const _DashCardHeader({required this.title, required this.showChevron});

  final String title;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 10,
              color: BmoColors.textMuted,
            ),
          ),
          if (showChevron) ...[
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: BmoColors.textMuted.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }
}
