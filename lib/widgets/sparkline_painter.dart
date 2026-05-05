import 'dart:math';

import 'package:flutter/material.dart';

/// Draws a miniature polyline chart of session total_ms values over time.
///
/// [values] should be ordered oldest index 0 → newest last.
/// Mirrors [CircularProgressPainter] — no external dependencies.
class SparklinePainter extends CustomPainter {
  final List<int> values;
  final Color color;
  final double strokeWidth;

  const SparklinePainter({
    required this.values,
    required this.color,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;

    if (values.length == 1) {
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        strokeWidth * 1.5,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);

    if (minVal == maxVal) {
      // All equal: flat horizontal line at vertical midpoint.
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final dx = size.width / (values.length - 1);

    double yFor(int v) =>
        size.height - ((v - minVal) / (maxVal - minVal)) * size.height;

    final path = Path()..moveTo(0, yFor(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(i * dx, yFor(values[i]));
    }
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);

    // Mark current session (last point) with a filled dot.
    final lastX = (values.length - 1) * dx;
    final lastY = yFor(values.last);
    canvas.drawCircle(
      Offset(lastX, lastY),
      strokeWidth * 1.5,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) {
    if (old.color != color || old.strokeWidth != strokeWidth) return true;
    // Compare by content so that a rebuilt-but-identical list does not cause
    // an unnecessary repaint (e.g. when build() calls .toList() each frame).
    if (old.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (old.values[i] != values[i]) return true;
    }
    return false;
  }
}
