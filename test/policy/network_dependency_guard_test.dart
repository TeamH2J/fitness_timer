// G2 — Network Dependency Guard
//
// Reads pubspec.yaml from the project root and asserts that no HTTP/network
// library is present in either dependencies: or dev_dependencies:.
// Runs on every `flutter test` call — blocks CI if a banned package is added.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Network dependency guard', () {
    const blockedPackages = [
      'http',
      'dio',
      'chopper',
      'retrofit',
      'graphql',
      'graphql_flutter',
      'websocket',
      'web_socket_channel',
      'supabase_flutter',
      'firebase_core',
    ];

    test('pubspec.yaml contains no banned network packages', () {
      // Resolve pubspec.yaml relative to the project root.
      // flutter test runs from the project root, so File('pubspec.yaml') works.
      final pubspecFile = File('pubspec.yaml');
      if (!pubspecFile.existsSync()) {
        fail('pubspec.yaml not found at ${pubspecFile.absolute.path}');
      }

      final lines = pubspecFile.readAsLinesSync();

      // Collect dependency keys from both dependency sections.
      // We are inside a dependency block when in dependencies: or
      // dev_dependencies: and a line is indented (starts with spaces).
      final depKeys = <String>[];
      bool inDepsBlock = false;

      for (final line in lines) {
        final trimmed = line.trim();

        // Detect section headers.
        if (trimmed == 'dependencies:' || trimmed == 'dev_dependencies:') {
          inDepsBlock = true;
          continue;
        }

        // A top-level key (no leading space) ends the deps block.
        if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
          inDepsBlock = false;
          continue;
        }

        if (!inDepsBlock) continue;

        // Dependency entries look like "  package_name: ^x.y.z" or
        // "  flutter:\n    sdk: flutter" — capture the key name.
        final match = RegExp(r'^\s{2}(\w[\w_]*)[\s:]').firstMatch(line);
        if (match != null) {
          depKeys.add(match.group(1)!);
        }
      }

      final violations = blockedPackages
          .where((pkg) => depKeys.contains(pkg))
          .toList();

      expect(
        violations,
        isEmpty,
        reason:
            'Blocked network package(s) found in pubspec.yaml: '
            '${violations.join(', ')}. '
            'Remove them to keep the v1.0 network-zero policy.',
      );
    });
  });
}
