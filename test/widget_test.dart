import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_timer/main.dart';

void main() {
  testWidgets('App boots with dark scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessTimerApp()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
