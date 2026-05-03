import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_timer/widgets/circular_progress_painter.dart';

void main() {
  group('CircularProgressPainter', () {
    const red = Color(0xFFFF0000);
    const grey = Color(0xFF808080);

    CircularProgressPainter painter(double progress) {
      return CircularProgressPainter(
        progress: progress,
        foreground: red,
        background: grey,
        strokeWidth: 12,
      );
    }

    test('shouldRepaint returns true when progress changes', () {
      final p1 = painter(0.0);
      final p2 = painter(0.5);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint returns false when progress unchanged', () {
      final p1 = painter(0.5);
      final p2 = painter(0.5);
      expect(p1.shouldRepaint(p2), isFalse);
    });

    test('shouldRepaint returns true when foreground color changes', () {
      final p1 = CircularProgressPainter(
        progress: 0.5,
        foreground: red,
        background: grey,
        strokeWidth: 12,
      );
      final p2 = CircularProgressPainter(
        progress: 0.5,
        foreground: Colors.blue,
        background: grey,
        strokeWidth: 12,
      );
      expect(p1.shouldRepaint(p2), isTrue);
    });

    testWidgets('paint at progress 0.0 does not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter(0.0),
              size: const Size(200, 200),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('paint at progress 0.5 does not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter(0.5),
              size: const Size(200, 200),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('paint at progress 1.0 does not throw', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter: painter(1.0),
              size: const Size(200, 200),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
