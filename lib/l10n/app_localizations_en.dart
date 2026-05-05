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
  String get itemRestDuration => 'Rest (s)';

  @override
  String get restNone => 'No rest';

  @override
  String get retry => 'Retry';

  @override
  String get pageNotFound => 'Page not found.';

  @override
  String get tabRoutines => 'Routines';

  @override
  String get tabTimer => 'Timer';

  @override
  String get tabSettings => 'Settings';

  @override
  String get timerTabPlaceholder => 'Select a routine from the Routines tab';

  @override
  String get goToRoutines => 'Go to Routines';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageKorean => 'Korean';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsSoundHaptic => 'Sound / Haptic';

  @override
  String get settingsTts => 'TTS';

  @override
  String get settingsBeep => 'Beep';

  @override
  String get settingsHaptic => 'Haptic';

  @override
  String get settingsDisplayFormat => 'Display Format';

  @override
  String get settingsFormatMmss => 'MM:SS';

  @override
  String get settingsFormatSeconds => 'Seconds';

  @override
  String get settingsAppInfo => 'App Info';

  @override
  String get settingsVersion => 'Version';

  @override
  String get tapToStart => 'Tap to start';

  @override
  String get tabStopwatch => 'Stopwatch';

  @override
  String get stopwatchStart => 'Start';

  @override
  String get stopwatchStop => 'Stop';

  @override
  String get stopwatchLap => 'Lap';

  @override
  String get stopwatchReset => 'Reset';

  @override
  String get stopwatchEmptyLaps => 'No laps recorded';

  @override
  String get stopwatchLapLabel => 'Lap';

  @override
  String get historyLaps => 'laps';

  @override
  String get stopwatchDetailTitle => 'Session Detail';

  @override
  String get stopwatchLabelHint => 'Add a label to compare with history…';

  @override
  String get stopwatchSaveLabel => 'Save';

  @override
  String get stopwatchCompareNoLabel =>
      'Add a label to compare with previous sessions.';

  @override
  String get stopwatchAggregateTotal => 'Total';

  @override
  String get stopwatchAggregateAvg => 'Avg Lap';

  @override
  String get stopwatchAggregateFastest => 'Fastest';

  @override
  String get stopwatchAggregateSlowest => 'Slowest';

  @override
  String get stopwatchPbBadge => 'PB';

  @override
  String get stopwatchTrendTitle => 'Trend';

  @override
  String get stopwatchLapDiff => 'Δ vs prev';

  @override
  String get stopwatchNoPrior => 'First session with this label.';
}
