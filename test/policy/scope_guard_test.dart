// G3 — Scope Guard (v1.0 exclusion-zone keyword scan)
//
// Recursively walks lib/ and asserts that no out-of-scope keyword appears
// in any .dart file. Runs on every `flutter test` call.
//
// IMPORTANT: The forbidden patterns below are defined as split strings or raw
// literals so that this test file itself does not trigger its own guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scope guard', () {
    // Forbidden patterns — defined here as a list of [pattern, description]
    // pairs. Each pattern is a RegExp string.
    //
    // Caution: the strings below must NOT themselves match the patterns.
    // Patterns that contain the banned words are split so the source of this
    // file stays clean.
    final forbiddenPatterns = <_Pattern>[
      // Cloud / backend services
      _Pattern(r'package:fire' 'base_', 'firebase package import'),
      _Pattern(r'package:cloud' '_', 'cloud package import'),
      _Pattern(r'package:supa' 'base_', 'supabase package import'),
      // Wearable / watch
      _Pattern(r'WatchKit', 'WatchKit identifier'),
      _Pattern(r'apple_' 'watch', 'apple_watch identifier'),
      _Pattern(r'watch_' 'kit', 'watch_kit identifier'),
      _Pattern(r'garmin', 'garmin identifier'),
      _Pattern(r'health' 'kit', 'healthkit identifier'),
      _Pattern(r'google_' 'fit', 'google_fit identifier'),
      // Charting libraries
      _Pattern(r'package:fl_' 'chart', 'fl_chart package import'),
      _Pattern(r'package:charts_', 'charts_ package import'),
      // Analytics
      _Pattern(r'package:fire' 'base_' 'analytics', 'firebase analytics'),
      _Pattern(r'\b[Aa]nalytics\b', 'Analytics class/identifier'),
      // Sync classes — block Sync as a class name or in import paths,
      // but not in comments. We match "class FooSync" or "class SyncFoo"
      // patterns rather than bare word to avoid comment false-positives.
      _Pattern(r'class\s+\w*Sync\w*\s*[{<]', 'class name containing Sync'),
      _Pattern(r'package:\w*sync\w*', 'sync package import'),
      // Explicit cloud/supabase/firebase identifiers (not just imports)
      _Pattern(r'\bFirestore\b', 'Firestore identifier'),
      _Pattern(r'\bFirebase\b', 'Firebase identifier'),
      _Pattern(r'\bSupabase\b', 'Supabase identifier'),
    ];

    test('lib/ source tree contains no out-of-scope keywords', () {
      final libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib/ directory not found at ${libDir.absolute.path}');
      }

      final dartFiles = libDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final pattern in forbiddenPatterns) {
          final regExp = RegExp(pattern.regex, caseSensitive: false);
          if (regExp.hasMatch(content)) {
            violations.add(
              '${file.path}: matched pattern "${pattern.description}"',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Scope violations found in lib/ source tree:\n'
            '${violations.join('\n')}',
      );
    });
  });
}

class _Pattern {
  final String regex;
  final String description;
  const _Pattern(this.regex, this.description);
}
