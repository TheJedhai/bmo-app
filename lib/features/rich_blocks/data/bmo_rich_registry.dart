import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';
import 'bmo_rich_block.dart';

/// Signature for building a rich-content widget from a [BmoRichBlock].
typedef BmoRichWidgetBuilder = Widget Function(BmoRichBlock block);

/// Global registry mapping rich-content [type] strings to widget builders.
///
/// Usage — register builders once at startup (e.g. in [main]):
/// ```dart
/// BmoRichRegistry.register('image', (block) => BmoRichImageCard(block: block));
/// ```
///
/// Unknown types render a [FallbackRichCard] so the UI never crashes or
/// silently drops content.
class BmoRichRegistry {
  BmoRichRegistry._();

  static final Map<String, BmoRichWidgetBuilder> _builders = {};

  /// Registers a builder for [type]. Overwrites any existing registration.
  static void register(String type, BmoRichWidgetBuilder builder) {
    _builders[type] = builder;
  }

  /// Returns the builder for [type], or `null` if not registered.
  static BmoRichWidgetBuilder? get(String type) => _builders[type];

  /// Builds a widget for [block], falling back to [FallbackRichCard] if the
  /// type has no registered builder.
  static Widget build(BmoRichBlock block) {
    final builder = _builders[block.type];
    if (builder != null) return builder(block);
    return FallbackRichCard(block: block);
  }

  /// Clears all registrations (useful in tests).
  static void reset() => _builders.clear();
}

/// Fallback widget for rich-content types that have no registered builder.
///
/// Renders a minimal, non-intrusive card showing the type name — content is
/// never silently dropped.
class FallbackRichCard extends StatelessWidget {
  final BmoRichBlock block;
  const FallbackRichCard({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: BmoColors.screenBg,
        border: Border.all(
          color: BmoColors.textMuted.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.widgets_outlined, size: 20, color: BmoColors.textMuted),
          const SizedBox(width: 8),
          Text(
            'Conteúdo: ${block.type}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: BmoColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
