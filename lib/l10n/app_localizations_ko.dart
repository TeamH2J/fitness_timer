// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '심플 홈트 타이머';

  @override
  String get emptyHome => '아직 루틴이 없어요';

  @override
  String get emptyHomeSubtitle => '+ 버튼으로 시작하세요';

  @override
  String get emptyHistory => '아직 완료된 운동이 없어요';

  @override
  String get addRoutine => '새 루틴';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get edit => '편집';

  @override
  String get cycle => '사이클';

  @override
  String get next => '다음';

  @override
  String get repsTarget => '회';

  @override
  String get completeTitle => '완료!';

  @override
  String get repeatRoutine => '다시 하기';

  @override
  String get goHome => '홈으로';

  @override
  String get history => '히스토리';

  @override
  String get routineTitle => '제목';

  @override
  String get prepTime => '준비 시간';

  @override
  String get cooldownTime => '쿨다운 시간';

  @override
  String get totalCycles => '반복 횟수';

  @override
  String get addItem => '+ 항목 추가';

  @override
  String get seconds => '초';

  @override
  String get errorLoadData => '데이터를 불러오지 못했습니다. 다시 시도하세요.';

  @override
  String get errorLoadRoutine => '루틴을 불러오지 못했습니다.';

  @override
  String get errorSave => '저장에 실패했습니다. 다시 시도하세요.';

  @override
  String get typeWorkTime => '시간';

  @override
  String get typeWorkReps => '횟수';

  @override
  String get typeRest => '휴식';

  @override
  String get exerciseName => '이름';

  @override
  String get duration => '시간 (초)';

  @override
  String get targetReps => '목표 횟수';

  @override
  String get itemRestDuration => '휴식 (초)';

  @override
  String get restNone => '휴식 없음';

  @override
  String get retry => '다시 시도';

  @override
  String get pageNotFound => '페이지를 찾을 수 없습니다.';
}
