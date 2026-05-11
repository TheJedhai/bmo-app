import 'package:flutter/material.dart';

const double _kRadius = 14;
const double _kTailLateralReach = 10;
const double _kHPadding = 14;
const double _kVPadding = 10;
const double _kTailBaseBottomInset = 16;
const double _kTailBaseSideInset = 14;
const double _kTipBottomInset = 7;

/// Bubble com forma de balão de fala. Desenha rounded rect + tail orgânico
/// como um único Path, então a borda emenda sem traço duplo na junção.
///
/// Tail sai da lateral inferior do lado do avatar e a ponta aponta
/// horizontalmente em direção ao avatar.
class SpeechBubble extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;
  final bool tailOnLeft;

  const SpeechBubble({
    super.key,
    required this.child,
    required this.color,
    required this.borderColor,
    required this.tailOnLeft,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpeechBubblePainter(
        color: color,
        borderColor: borderColor,
        tailOnLeft: tailOnLeft,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kHPadding + (tailOnLeft ? _kTailLateralReach : 0),
          _kVPadding,
          _kHPadding + (tailOnLeft ? 0 : _kTailLateralReach),
          _kVPadding,
        ),
        child: child,
      ),
    );
  }
}

class _SpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool tailOnLeft;

  _SpeechBubblePainter({
    required this.color,
    required this.borderColor,
    required this.tailOnLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = _kRadius;
    final t = _kTailLateralReach;
    final tipY = h - _kTipBottomInset;

    final bodyLeft = tailOnLeft ? t : 0.0;
    final bodyRight = tailOnLeft ? w : w - t;

    final path = Path();

    // Top-left corner start
    path.moveTo(bodyLeft + r, 0);
    // Top edge
    path.lineTo(bodyRight - r, 0);
    // Top-right corner
    path.quadraticBezierTo(bodyRight, 0, bodyRight, r);
    // Right edge
    path.lineTo(bodyRight, h - r);

    if (tailOnLeft) {
      // Bottom-right rounded corner
      path.quadraticBezierTo(bodyRight, h, bodyRight - r, h);
      // Bottom edge to tail base
      path.lineTo(bodyLeft + _kTailBaseBottomInset, h);
      // Tail outward curve to tip (down-out-left)
      path.quadraticBezierTo(
        bodyLeft + 4, h,                      // control: just inside body bottom
        0, tipY,                              // tip at canvas left edge
      );
      // Tail return curve to body's left edge above corner area
      path.quadraticBezierTo(
        bodyLeft - 1, h - _kTailBaseSideInset + 2,
        bodyLeft, h - _kTailBaseSideInset,
      );
      // Left edge up
      path.lineTo(bodyLeft, r);
      // Top-left corner
      path.quadraticBezierTo(bodyLeft, 0, bodyLeft + r, 0);
    } else {
      // User: tail at bottom-right (mirrored)
      // Currently at (bodyRight, h - r). Skip normal bottom-right corner.
      path.quadraticBezierTo(
        bodyRight + 1, h - _kTailBaseSideInset + 2,
        w, tipY,                              // tip at canvas right edge
      );
      path.quadraticBezierTo(
        bodyRight - 4, h,
        bodyRight - _kTailBaseBottomInset, h,
      );
      // Bottom edge to bottom-left corner
      path.lineTo(bodyLeft + r, h);
      // Bottom-left rounded corner
      path.quadraticBezierTo(bodyLeft, h, bodyLeft, h - r);
      // Left edge
      path.lineTo(bodyLeft, r);
      // Top-left corner
      path.quadraticBezierTo(bodyLeft, 0, bodyLeft + r, 0);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SpeechBubblePainter old) =>
      old.color != color ||
      old.borderColor != borderColor ||
      old.tailOnLeft != tailOnLeft;
}
