import 'package:flutter/material.dart';

import '../../../core/theme/bmo_theme.dart';

/// Chassi visual comum de todo widget da dashboard.
///
/// Cada card tem um [accent] que define cor da borda, glow pulsante,
/// cantoneiras em L e header.
///
/// [pulseDelay] atrasa o início da animação de glow para criar
/// um efeito cascata entre os cards.
///
/// Header opcional: título em PressStart2P 11px, uppercase, cor accent.
/// Chevron › à direita quando [onTap] != null.
///
/// Hover (desktop): AnimatedContainer 150ms, translateY −3px + scale 1.008.
///
/// Estrutura:
/// MouseRegion → AnimatedContainer →
///   Stack [
///     Container (superfície + borda + glow),
///     CustomPaint (cantoneiras L),
///     Column (header + child, mainAxisSize.min)
///   ]
class DashCard extends StatefulWidget {
  const DashCard({
    super.key,
    this.title,
    this.onTap,
    required this.accent,
    this.pulseDelay = Duration.zero,
    required this.child,
  });

  final String? title;
  final void Function(BuildContext)? onTap;
  final Color accent;
  final Duration pulseDelay;
  final Widget child;

  /// Número em destaque no estilo dashboard:
  /// PressStart2P 34px, cor [accent], com sombra glow.
  static Widget highlightNumber(String text, Color accent) {
    return Text(
      text,
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
    );
  }

  @override
  State<DashCard> createState() => _DashCardState();
}

class _DashCardState extends State<DashCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _glowAnimation = Tween<double>(begin: 14, end: 24).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Inicia o glow após o pulseDelay para efeito cascata.
    if (widget.pulseDelay > Duration.zero) {
      Future.delayed(widget.pulseDelay, () {
        if (mounted) {
          _glowController.repeat(reverse: true);
        }
      });
    } else {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color get _surfaceColor => Color.alphaBlend(
        widget.accent.withValues(alpha: 0.10),
        BmoColors.screenBgElevated,
      );

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: () {
          final m = Matrix4.identity();
          m.setTranslationRaw(0.0, _isHovered ? -3.0 : 0.0, 0.0);
          final s = _isHovered ? 1.008 : 1.0;
          m.setEntry(0, 0, s);
          m.setEntry(1, 1, s);
          return m;
        }(),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accent.withValues(alpha: 0.50),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.18),
                    blurRadius: _glowAnimation.value,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Cantoneiras em L nos 4 cantos
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: _LCornerPainter(
                          color: widget.accent,
                          strokeLength: 18,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                  // Conteúdo do card
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap:
                          widget.onTap != null
                              ? () => widget.onTap!(context)
                              : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null)
                            _DashCardHeader(
                              title: widget.title!,
                              accent: widget.accent,
                              showChevron: widget.onTap != null,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: widget.child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cantoneiras em L nos 4 cantos do card.
///
/// Cada canto tem dois traços partindo da borda: um horizontal e um
/// vertical, formando um "L". Os traços têm [strokeLength] de comprimento
/// e [strokeWidth] de espessura, na cor [color].
class _LCornerPainter extends CustomPainter {
  const _LCornerPainter({
    required this.color,
    required this.strokeLength,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final inset = strokeWidth / 2 + 3; // ligeiro recuo da borda

    // Superior esquerdo
    _drawCorner(canvas, paint, inset, inset, 1, 1);
    // Superior direito
    _drawCorner(canvas, paint, size.width - inset, inset, -1, 1);
    // Inferior esquerdo
    _drawCorner(canvas, paint, inset, size.height - inset, 1, -1);
    // Inferior direito
    _drawCorner(
      canvas,
      paint,
      size.width - inset,
      size.height - inset,
      -1,
      -1,
    );
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    int dirX,
    int dirY,
  ) {
    // Traço horizontal
    canvas.drawLine(
      Offset(x, y),
      Offset(x + dirX * strokeLength, y),
      paint,
    );
    // Traço vertical
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + dirY * strokeLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LCornerPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeLength != oldDelegate.strokeLength ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

class _DashCardHeader extends StatelessWidget {
  const _DashCardHeader({
    required this.title,
    required this.accent,
    required this.showChevron,
  });

  final String title;
  final Color accent;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: 11,
              color: accent,
            ),
          ),
          if (showChevron) ...[
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: accent.withValues(alpha: 0.6),
            ),
          ],
        ],
      ),
    );
  }
}
