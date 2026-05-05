import 'package:fitness_timer/widgets/sparkline_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const blue = Color(0xFF2196F3);

  SparklinePainter makePainter(List<int> values) =>
      SparklinePainter(values: values, color: blue);

  group('SparklinePainter', () {
    // SP-1: empty values — paint completes without exception
    testWidgets('SP-1: empty values paints without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: CustomPaint(
                painter: makePainter([]),
                size: const Size(200, 48),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // SP-2: single value — dot drawn, no exception
    testWidgets('SP-2: single value paints a dot without exception',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: CustomPaint(
                painter: makePainter([5000]),
                size: const Size(200, 48),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // SP-3: two values — shouldRepaint returns true when list differs
    test('SP-3: shouldRepaint returns true when values list changes', () {
      final p1 = makePainter([5000, 4000]);
      final p2 = makePainter([5000, 3000]);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    // SP-4: all-equal values — horizontal line, no divide-by-zero
    testWidgets('SP-4: all-equal values paints without exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: CustomPaint(
                painter: makePainter([5000, 5000, 5000]),
                size: const Size(200, 48),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    // SP-5: 10-point path — shouldRepaint returns false for same values instance
    test('SP-5: shouldRepaint returns false when same values list object passed',
        () {
      final values = List.generate(10, (i) => 4000 + i * 200);
      final p1 = SparklinePainter(values: values, color: blue);
      final p2 = SparklinePainter(values: values, color: blue);
      expect(p1.shouldRepaint(p2), isFalse);
    });

    // Extra: 10-point path paints without exception
    testWidgets('SP-5b: 10-point sparkline paints without exception',
        (tester) async {
      final values = List.generate(10, (i) => 4000 + i * 200);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: CustomPaint(
                painter: makePainter(values),
                size: const Size(200, 48),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
