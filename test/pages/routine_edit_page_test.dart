import 'package:fitness_timer/l10n/app_localizations.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/models/routine.dart';
import 'package:fitness_timer/pages/routine_edit_page.dart';
import 'package:fitness_timer/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_database_service.dart';

Widget buildEditPage({
  required String? routineId,
  required FakeDatabaseService fakeDb,
}) {
  return ProviderScope(
    overrides: [
      databaseServiceProvider.overrideWithValue(fakeDb),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RoutineEditPage(routineId: routineId),
    ),
  );
}

void main() {
  group('T2 — RoutineEditPage', () {
    testWidgets('T2.1 new mode: tapping add-item button adds a row',
        (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildEditPage(routineId: null, fakeDb: fakeDb));
      await tester.pumpAndSettle();

      // Initially no drag-handle icons (no items)
      expect(find.byIcon(Icons.drag_handle), findsNothing);

      // Tap the add item button
      await tester.tap(find.text('+ Add item'));
      await tester.pumpAndSettle();

      // Now one drag handle should appear
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets(
        'T2.2 new mode save: tapping save calls upsertRoutineWithItems once',
        (tester) async {
      final fakeDb = FakeDatabaseService();

      await tester.pumpWidget(buildEditPage(routineId: null, fakeDb: fakeDb));
      await tester.pumpAndSettle();

      // Enter a title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'My New Routine');
      await tester.pumpAndSettle();

      // Tap save icon
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(fakeDb.upsertCallCount, 1);
    });

    testWidgets('T2.3 edit mode: existing routine title is displayed',
        (tester) async {
      final fakeDb = FakeDatabaseService(
        routines: [
          const Routine(
            id: 'r1',
            title: 'Existing Routine',
            prepTime: 5,
            cooldownTime: 10,
            totalCycles: 2,
          ),
        ],
        items: {
          'r1': [
            const ExerciseItem(
              id: 'item-1',
              routineId: 'r1',
              orderIndex: 0,
              type: ExerciseType.WORK_TIME,
              duration: 30,
              name: 'Squats',
            ),
          ],
        },
      );

      await tester.pumpWidget(buildEditPage(routineId: 'r1', fakeDb: fakeDb));
      // Allow async load to complete
      await tester.pumpAndSettle();
      await tester.pumpAndSettle(); // extra settle for async state update

      // The title text field should contain the loaded routine title
      expect(find.text('Existing Routine'), findsOneWidget);
    });
  });
}
