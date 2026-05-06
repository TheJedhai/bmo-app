import 'package:flutter/material.dart';
import '../theme/bmo_theme.dart';

const _kMobileBreakpoint = 600.0;

/// Casca visual do BMO ocupando a viewport inteira: borda verde nas 4
/// extremidades + tela escura no meio cobrindo todo o resto do espaço.
class BmoFrame extends StatelessWidget {
  final Widget child;
  const BmoFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _kMobileBreakpoint;

    final borderPadding = isMobile ? 12.0 : 28.0;
    final innerRadius = isMobile ? 12.0 : 18.0;

    return Container(
      color: BmoColors.bodyGreen,
      padding: EdgeInsets.all(borderPadding),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: BmoColors.screenBg,
          borderRadius: BorderRadius.circular(innerRadius),
        ),
        child: child,
      ),
    );
  }
}
