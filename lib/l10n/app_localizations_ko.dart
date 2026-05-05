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

  @override
  String get tabRoutines => '루틴';

  @override
  String get tabTimer => '타이머';

  @override
  String get tabSettings => '설정';

  @override
  String get timerTabPlaceholder => '루틴 탭에서 루틴을 선택하세요';

  @override
  String get goToRoutines => '루틴으로 이동';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsLanguageSystem => '시스템';

  @override
  String get settingsLanguageKorean => '한국어';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsSoundHaptic => '사운드 / 햅틱';

  @override
  String get settingsTts => 'TTS';

  @override
  String get settingsBeep => 'Beep';

  @override
  String get settingsHaptic => '진동';

  @override
  String get settingsDisplayFormat => '표시 형식';

  @override
  String get settingsFormatMmss => 'MM:SS';

  @override
  String get settingsFormatSeconds => '초 단위';

  @override
  String get settingsAppInfo => '앱 정보';

  @override
  String get settingsVersion => '버전';

  @override
  String get tapToStart => '탭 하여 시작';

  @override
  String get tabStopwatch => '스톱워치';

  @override
  String get stopwatchStart => '시작';

  @override
  String get stopwatchStop => '정지';

  @override
  String get stopwatchLap => '랩';

  @override
  String get stopwatchReset => '초기화';

  @override
  String get stopwatchEmptyLaps => '기록된 랩이 없습니다';

  @override
  String get stopwatchLapLabel => '랩';

  @override
  String get historyLaps => '랩';

  @override
  String get stopwatchDetailTitle => '세션 상세';

  @override
  String get stopwatchLabelHint => '라벨을 추가하면 이전 기록과 비교할 수 있어요…';

  @override
  String get stopwatchSaveLabel => '저장';

  @override
  String get stopwatchCompareNoLabel => '라벨을 추가하면 이전 기록과 비교할 수 있어요.';

  @override
  String get stopwatchAggregateTotal => '총 시간';

  @override
  String get stopwatchAggregateAvg => '평균 랩';

  @override
  String get stopwatchAggregateFastest => '최고 랩';

  @override
  String get stopwatchAggregateSlowest => '최저 랩';

  @override
  String get stopwatchPbBadge => 'PB';

  @override
  String get stopwatchTrendTitle => '추이';

  @override
  String get stopwatchLapDiff => '직전 대비';

  @override
  String get stopwatchNoPrior => '이 라벨의 첫 세션입니다.';
}
