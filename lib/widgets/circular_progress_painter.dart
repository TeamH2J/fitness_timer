import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a circular progress arc.
///
/// [progress] ranges from 0.0 (full remaining) to 1.0 (all elapsed).
/// The arc sweeps clockwise from the top, shrinking as time passes.
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color foreground;
  final Color background;
  final double strokeWidth;

  const CircularProgressPainter({
    required this.progress,
    required this.foreground,
    required this.background,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background track (full circle)
    canvas.drawCircle(center, radius, bgPaint);

    // Draw foreground arc — remaining time arc (shrinks as progress increases)
    final remaining = (1.0 - progress).clamp(0.0, 1.0);
    if (remaining > 0) {
      final fgPaint = Paint()
        ..color = foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -pi / 2; // top
      final sweepAngle = 2 * pi * remaining;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.foreground != foreground ||
        oldDelegate.background != background ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
