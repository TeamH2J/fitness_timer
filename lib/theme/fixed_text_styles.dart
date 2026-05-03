import 'package:flutter/material.dart';

/// Fixed-size text styles that ignore system text scale.
/// Use with [TextScaler.noScaling] at call sites:
///   Text(text, style: FixedTextStyles.largeNumber, textScaler: TextScaler.noScaling)
class FixedTextStyles {
  FixedTextStyles._();

  /// Large timer digit — 120pt bold white. Immune to system textScale.
  static const TextStyle largeNumber = TextStyle(
    fontSize: 120,
    fontWeight: FontWeight.w700,
    color: Color(0xFFFFFFFF),
  );

  /// Secondary timer digit — 48pt semi-bold white. Immune to system textScale.
  static const TextStyle largeNumberSecondary = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: Color(0xFFFFFFFF),
  );
}
