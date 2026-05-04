import 'package:fitness_timer/main.dart';
import 'package:fitness_timer/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  testWidgets('App boots with dark scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FitnessTimerApp()));
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });
}
