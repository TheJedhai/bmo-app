import 'package:flutter/material.dart';

import '../theme/bmo_theme.dart';

/// Círculo escuro ([BmoColors.screenBg]) usado como fundo de contraste
/// para controles — sobre o chassi verde claro ([BmoFrame]) e sobre o
/// conteúdo que desliza por baixo da [BmoTopBar] na dashboard mobile.
class DarkCircle extends StatelessWidget {
  final double diameter;
  final Widget child;

  const DarkCircle({super.key, required this.diameter, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: const BoxDecoration(
        color: BmoColors.screenBg,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}
