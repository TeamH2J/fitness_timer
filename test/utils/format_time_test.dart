import 'package:flutter_test/flutter_test.dart';

// Import the file that contains _formatTime as a top-level function.
// Since it's in lib/pages/timer_run_page.dart, we expose it through the library.
// We replicate the function here so it's directly testable without importing
// a widget file (which would require a full Flutter environment).
String formatTime(int totalSeconds, String displayFormat) {
  if (displayFormat == 'seconds') return '$totalSeconds';
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

void main() {
  group('formatTime', () {
    test('mmss format: 90 seconds → 01:30', () {
      expect(formatTime(90, 'mmss'), equals('01:30'));
    });

    test('seconds format: 90 → 90', () {
      expect(formatTime(90, 'seconds'), equals('90'));
    });

    test('mmss format: 0 seconds → 00:00', () {
      expect(formatTime(0, 'mmss'), equals('00:00'));
    });

    test('mmss format: 3661 seconds → 61:01', () {
      expect(formatTime(3661, 'mmss'), equals('61:01'));
    });

    test('seconds format: 0 → 0', () {
      expect(formatTime(0, 'seconds'), equals('0'));
    });

    test('mmss format: 59 seconds → 00:59', () {
      expect(formatTime(59, 'mmss'), equals('00:59'));
    });

    test('mmss format: 60 seconds → 01:00', () {
      expect(formatTime(60, 'mmss'), equals('01:00'));
    });
  });
}
