import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple Home Workout Timer'**
  String get appTitle;

  /// No description provided for @emptyHome.
  ///
  /// In en, this message translates to:
  /// **'No routines yet'**
  String get emptyHome;

  /// No description provided for @emptyHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to get started'**
  String get emptyHomeSubtitle;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No completed workouts yet'**
  String get emptyHistory;

  /// No description provided for @addRoutine.
  ///
  /// In en, this message translates to:
  /// **'New Routine'**
  String get addRoutine;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get cycle;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @repsTarget.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get repsTarget;

  /// No description provided for @completeTitle.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get completeTitle;

  /// No description provided for @repeatRoutine.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatRoutine;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get goHome;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @routineTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get routineTitle;

  /// No description provided for @prepTime.
  ///
  /// In en, this message translates to:
  /// **'Prep time'**
  String get prepTime;

  /// No description provided for @cooldownTime.
  ///
  /// In en, this message translates to:
  /// **'Cooldown time'**
  String get cooldownTime;

  /// No description provided for @totalCycles.
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get totalCycles;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'+ Add item'**
  String get addItem;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get seconds;

  /// No description provided for @errorLoadData.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data. Please retry.'**
  String get errorLoadData;

  /// No description provided for @errorLoadRoutine.
  ///
  /// In en, this message translates to:
  /// **'Failed to load routine.'**
  String get errorLoadRoutine;

  /// No description provided for @errorSave.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Please retry.'**
  String get errorSave;

  /// No description provided for @typeWorkTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get typeWorkTime;

  /// No description provided for @typeWorkReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get typeWorkReps;

  /// No description provided for @typeRest.
  ///
  /// In en, this message translates to:
  /// **'Rest'**
  String get typeRest;

  /// No description provided for @exerciseName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get exerciseName;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration (s)'**
  String get duration;

  /// No description provided for @targetReps.
  ///
  /// In en, this message translates to:
  /// **'Reps'**
  String get targetReps;

  /// No description provided for @itemRestDuration.
  ///
  /// In en, this message translates to:
  /// **'Rest (s)'**
  String get itemRestDuration;

  /// No description provided for @restNone.
  ///
  /// In en, this message translates to:
  /// **'No rest'**
  String get restNone;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found.'**
  String get pageNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
