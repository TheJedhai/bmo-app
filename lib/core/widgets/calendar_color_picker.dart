import 'package:flutter/material.dart';

import '../theme/bmo_theme.dart';

/// Visual circle color picker for calendar palette.
///
/// Uses [BmoColors.calendarPalette] as the single source of truth.
class CalendarColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onChanged;
  final double size;
  final double spacing;

  const CalendarColorPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
    this.size = 32,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      children: BmoColors.calendarPalette.map((color) {
        final selected = selectedColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: BmoColors.textPrimary,
                      width: 2.5,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
