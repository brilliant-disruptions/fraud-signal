import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tiles a faint diagonal watermark across its child. Applied to every
/// evidence card so a screenshot carries who viewed it and when.
class Watermarked extends StatelessWidget {
  const Watermarked({super.key, required this.text, required this.child});
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.045);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _WatermarkPainter(text: text, color: color)),
          ),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    const stepX = 300.0;
    const stepY = 150.0;
    canvas.save();
    canvas.rotate(-math.pi / 9);
    for (var y = -size.height; y < size.height * 1.5; y += stepY) {
      for (var x = -size.width; x < size.width * 1.5; x += stepX) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter old) => old.text != text || old.color != color;
}
