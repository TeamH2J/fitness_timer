import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_timer/models/exercise_item.dart';
import 'package:fitness_timer/providers/routine_edit_provider.dart';

import '../helpers/fake_database_service.dart';

void main() {
  group('RoutineEditNotifier', () {
    late FakeDatabaseService fakeDb;
    late RoutineEditNotifier notifier;

    setUp(() {
      fakeDb = FakeDatabaseService();
      notifier = RoutineEditNotifier(fakeDb, null);
    });

    test('initial state has default values', () {
      expect(notifier.state.title, '');
      expect(notifier.state.prepTime, 0);
      expect(notifier.state.cooldownTime, 0);
      expect(notifier.state.totalCycles, 1);
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isSaving, false);
    });

    test('setTitle updates title', () {
      notifier.setTitle('My Routine');
      expect(notifier.state.title, 'My Routine');
    });

    test('setPrepTime clamps to 0-60', () {
      notifier.setPrepTime(100);
      expect(notifier.state.prepTime, 60);
      notifier.setPrepTime(-5);
      expect(notifier.state.prepTime, 0);
      notifier.setPrepTime(30);
      expect(notifier.state.prepTime, 30);
    });

    test('setCooldownTime clamps to 0-120', () {
      notifier.setCooldownTime(200);
      expect(notifier.state.cooldownTime, 120);
      notifier.setCooldownTime(-1);
      expect(notifier.state.cooldownTime, 0);
      notifier.setCooldownTime(60);
      expect(notifier.state.cooldownTime, 60);
    });

    test('setTotalCycles clamps to 1-10', () {
      notifier.setTotalCycles(20);
      expect(notifier.state.totalCycles, 10);
      notifier.setTotalCycles(0);
      expect(notifier.state.totalCycles, 1);
      notifier.setTotalCycles(5);
      expect(notifier.state.totalCycles, 5);
    });

    test('addItem adds an ExerciseItem', () {
      expect(notifier.state.items.length, 0);
      notifier.addItem();
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.type, ExerciseType.WORK_TIME);
    });

    test('addItem appends successive items in order', () {
      notifier.addItem();
      notifier.addItem();
      expect(notifier.state.items.length, 2);
      expect(notifier.state.items[0].orderIndex, 0);
      expect(notifier.state.items[1].orderIndex, 1);
    });

    test('removeItem removes correct item and re-indexes', () {
      notifier.addItem(); // index 0
      notifier.addItem(); // index 1
      notifier.addItem(); // index 2
      notifier.removeItem(1); // remove middle
      expect(notifier.state.items.length, 2);
      expect(notifier.state.items[0].orderIndex, 0);
      expect(notifier.state.items[1].orderIndex, 1);
    });

    test('updateItem replaces item at index', () {
      notifier.addItem();
      final original = notifier.state.items.first;
      final updated = original.copyWith(name: 'Updated');
      notifier.updateItem(0, updated);
      expect(notifier.state.items.first.name, 'Updated');
    });

    test('reorderItems moves item and re-indexes', () {
      notifier.addItem();
      notifier.addItem();
      notifier.addItem();
      final ids = notifier.state.items.map((i) => i.id).toList();
      notifier.reorderItems(0, 2); // move first item to position after second
      expect(notifier.state.items[0].id, ids[1]);
      expect(notifier.state.items[1].id, ids[0]);
      for (var i = 0; i < notifier.state.items.length; i++) {
        expect(notifier.state.items[i].orderIndex, i);
      }
    });

    test('save calls upsertRoutineWithItems and returns true', () async {
      notifier.setTitle('Test Routine');
      notifier.addItem();
      final success = await notifier.save();
      expect(success, isTrue);
      expect(fakeDb.upsertCallCount, 1);
      expect(notifier.state.isSaving, false);
    });

    test('save with empty items still calls upsert', () async {
      notifier.setTitle('Empty');
      final success = await notifier.save();
      expect(success, isTrue);
      expect(fakeDb.upsertCallCount, 1);
    });
  });
}
