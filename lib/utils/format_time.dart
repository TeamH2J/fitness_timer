/// Returns a formatted time string based on [displayFormat].
///
/// [totalSeconds] must be >= 0.
/// [displayFormat] is either `'mmss'` (MM:SS) or `'seconds'` (raw integer).
String formatTime(int totalSeconds, String displayFormat) {
  if (displayFormat == 'seconds') return '$totalSeconds';
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
