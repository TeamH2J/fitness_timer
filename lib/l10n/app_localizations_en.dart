// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Simple Home Workout Timer';

  @override
  String get emptyHome => 'No routines yet';

  @override
  String get emptyHomeSubtitle => 'Tap + to get started';

  @override
  String get emptyHistory => 'No completed workouts yet';

  @override
  String get addRoutine => 'New Routine';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get cycle => 'Cycle';

  @override
  String get next => 'Next';

  @override
  String get repsTarget => 'reps';

  @override
  String get completeTitle => 'Done!';

  @override
  String get repeatRoutine => 'Repeat';

  @override
  String get goHome => 'Home';

  @override
  String get history => 'History';

  @override
  String get routineTitle => 'Title';

  @override
  String get prepTime => 'Prep time';

  @override
  String get cooldownTime => 'Cooldown time';

  @override
  String get totalCycles => 'Cycles';

  @override
  String get addItem => '+ Add item';

  @override
  String get seconds => 's';

  @override
  String get errorLoadData => 'Failed to load data. Please retry.';

  @override
  String get errorLoadRoutine => 'Failed to load routine.';

  @override
  String get errorSave => 'Save failed. Please retry.';

  @override
  String get typeWorkTime => 'Time';

  @override
  String get typeWorkReps => 'Reps';

  @override
  String get typeRest => 'Rest';

  @override
  String get exerciseName => 'Name';

  @override
  String get duration => 'Duration (s)';

  @override
  String get targetReps => 'Reps';

  @override
  String get retry => 'Retry';

  @override
  String get pageNotFound => 'Page not found.';
}
