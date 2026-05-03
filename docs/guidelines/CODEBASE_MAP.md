# Codebase Map — fitnessTimer

> AI 에이전트 / 신규 컨트리뷰터를 위한 폴더·도메인 navigation 맵.
> 클래스/파일을 찾거나 "기능 X를 어디에 추가하지?" 같은 질문에 빠르게 답하기 위한 문서.

**이 문서 사용법**: §2 트리로 위치 파악 → §3 도메인 맵으로 의존성 확인 → §5 의사결정 가이드로 신규 코드 위치 결정 → §6 Lookup 표로 클래스명 ↔ 파일 매핑.

---

## 1. Overview

**fitnessTimer** — 오프라인 전용 인터벌 트레이닝 타이머 앱 (iOS 16.0+ / Android API 26+).

- 광고 없음, 계정 없음, 네트워크 없음.
- 다크 테마 전용.
- 기술 스택: **Flutter 3.x / Dart 3.x**, **Riverpod** (상태 관리), **sqflite** (로컬 DB), **go_router** (라우팅), **just_audio + flutter_tts + vibration** (피드백).

---

## 2. 폴더 트리

```
lib/
├── main.dart                          # 앱 진입점, ProviderScope, 초기화
├── l10n/                              # 로컬라이제이션 (한국어/영어)
│   ├── app_localizations.dart
│   ├── app_localizations_en.dart
│   └── app_localizations_ko.dart
├── models/                            # 순수 데이터 모델 (DB ↔ Dart 매핑)
│   ├── routine.dart                   # Routine
│   ├── exercise_item.dart             # ExerciseItem, ExerciseType
│   ├── history.dart                   # History
│   └── feedback_preferences.dart      # FeedbackPreferences (비영속)
├── services/
│   ├── database_service.dart          # DatabaseService (sqflite CRUD)
│   ├── timer/                         # 타이머 엔진
│   │   ├── timer_engine.dart          # TimerEngine
│   │   ├── timer_state.dart           # TimerSnapshot, TimerState, TimerPhase
│   │   ├── timer_event.dart           # TimerEvent sealed class 계층
│   │   └── clock.dart                 # Clock, SystemClock, FakeClock
│   ├── feedback/                      # 오디오·햅틱·TTS 피드백
│   │   ├── feedback_controller.dart   # FeedbackController (오케스트레이터)
│   │   ├── tts_service.dart           # TtsService
│   │   ├── audio_feedback_service.dart# AudioFeedbackService
│   │   ├── haptic_service.dart        # HapticService
│   │   └── audio_session_configurator.dart # AudioSessionConfigurator
│   └── os/                            # OS 통합 (wakelock, 포그라운드, 알림)
│       ├── timer_os_bridge.dart       # TimerOsBridge (어댑터)
│       ├── wakelock_manager.dart      # WakelockManager
│       ├── app_lifecycle_observer.dart# AppLifecycleObserver
│       ├── foreground_service_controller.dart # ForegroundServiceController
│       ├── notification_throttler.dart# NotificationThrottler
│       └── platform_info.dart         # PlatformInfo
├── providers/                         # Riverpod providers
│   ├── database_provider.dart         # databaseServiceProvider
│   ├── home_provider.dart             # allRoutinesProvider, refreshableRoutinesProvider 등
│   ├── routine_edit_provider.dart     # RoutineEditNotifier, routineEditProvider
│   ├── timer_engine_provider.dart     # TimerEngineNotifier, timerEngineProvider
│   ├── feedback_provider.dart         # feedbackControllerProvider
│   └── os_provider.dart              # osProvider
├── pages/                             # 화면 단위 위젯 (ConsumerWidget 기반)
│   ├── home_page.dart                 # HomePage
│   ├── routine_edit_page.dart         # RoutineEditPage
│   ├── timer_run_page.dart            # TimerRunPage
│   ├── complete_page.dart             # CompletePage
│   └── history_page.dart             # HistoryPage
├── widgets/                           # 재사용 가능한 커스텀 위젯
│   └── circular_progress_painter.dart # CircularProgressPainter
├── routing/                           # go_router 라우팅 설정
│   └── app_router.dart               # appRouter (GoRouter 싱글턴)
└── theme/                             # 테마 / 텍스트 스타일
    ├── app_theme.dart                 # AppTheme
    └── fixed_text_styles.dart         # FixedTextStyles
```

---

## 3. 도메인 맵

| 도메인 | 위치 | 핵심 파일 | 역할 |
|--------|------|-----------|------|
| **Timer Engine** | `lib/services/timer/` | `timer_engine.dart`, `timer_state.dart`, `timer_event.dart`, `clock.dart` | 인터벌 타이머 핵심 로직. 250ms ticker, phase queue 관리, `TimerSnapshot` / `TimerEvent` stream 방출 |
| **Feedback** | `lib/services/feedback/` | `feedback_controller.dart`, `tts_service.dart`, `audio_feedback_service.dart`, `haptic_service.dart`, `audio_session_configurator.dart` | TTS / beep / haptic 피드백 오케스트레이션. `FeedbackController`가 `TimerEvent` stream을 구독하고 `FeedbackPreferences` 플래그에 따라 각 서비스 호출 |
| **OS Integration** | `lib/services/os/` | `timer_os_bridge.dart`, `wakelock_manager.dart`, `foreground_service_controller.dart`, `notification_throttler.dart`, `app_lifecycle_observer.dart`, `platform_info.dart` | 화면 켜짐 유지, Android 포그라운드 서비스, 잠금화면 알림, 앱 생명주기 감지 |
| **DB / Models** | `lib/services/database_service.dart`, `lib/models/` | `database_service.dart`, `routine.dart`, `exercise_item.dart`, `history.dart`, `feedback_preferences.dart` | sqflite 기반 CRUD. 3개 테이블 (`routines`, `exercise_items`, `histories`). FK ON DELETE CASCADE |
| **UI** | `lib/pages/`, `lib/widgets/`, `lib/routing/`, `lib/theme/` | 5개 페이지 + `circular_progress_painter.dart` + `app_router.dart` + `app_theme.dart` | ConsumerWidget 기반 화면, go_router 선언형 라우팅, 다크 테마 전용 |
| **Providers** | `lib/providers/` | 6개 provider 파일 | Riverpod으로 비즈니스 로직 노출. TimerEngine 생명주기 관리 포함 |

### 의존성 방향 (단방향)

```
Pages / Widgets
    │
    ▼
Providers (Riverpod)
    │
    ├──▶ TimerEngine (services/timer/)
    ├──▶ DatabaseService (services/)
    ├──▶ FeedbackController (services/feedback/)
    └──▶ TimerOsBridge (services/os/)
             │
             ▼
         OS APIs / Platform Channels
```

모델(`lib/models/`)은 모든 레이어에서 참조 가능한 순수 데이터 계층이다.

---

## 4. 명명 규칙

| 항목 | 규칙 | 예시 |
|------|------|------|
| 파일명 | `snake_case.dart` | `timer_engine.dart`, `feedback_controller.dart` |
| 클래스명 | `PascalCase` | `TimerEngine`, `FeedbackController` |
| Provider 변수 | `camelCase` + `Provider` suffix | `timerEngineProvider`, `databaseServiceProvider` |
| Notifier 클래스 | `PascalCase` + `Notifier` suffix | `TimerEngineNotifier`, `RoutineEditNotifier` |
| enum | `PascalCase` (enum 자체), 값은 `camelCase` 또는 `UPPER_CASE` | `TimerState { idle, running }`, `ExerciseType { WORK_TIME, WORK_REPS, REST }` |
| sealed event | `PascalCase` 동사+명사 | `PhaseStarted`, `PhaseEnded`, `RoutineCompleted` |
| 테스트 파일 | `<대상파일명>_test.dart` | `timer_engine_test.dart` |
| 테스트 헬퍼 | `test/helpers/` | `fake_database_service.dart` |

**Provider 패턴 요약**:
- 서비스 단순 주입 → `Provider<T>`
- 비동기 데이터 조회 → `FutureProvider<T>` (`.family`, `.autoDispose` 조합)
- 상태 관리 + 액션 → `StateNotifierProvider`
- 단순 카운터/플래그 → `StateProvider<T>`

---

## 5. "어디에 추가할까?" 의사결정 가이드

| 추가할 것 | 위치 | 비고 |
|-----------|------|------|
| 새 DB 테이블 / 모델 | `lib/models/<name>.dart` + `lib/services/database_service.dart` | `fromMap` / `toMap` / `copyWith` 구현 필수 |
| 새 화면 | `lib/pages/<name>_page.dart` | `ConsumerWidget` 또는 `ConsumerStatefulWidget`. `app_router.dart`에 경로 추가 |
| 새 라우트 | `lib/routing/app_router.dart` | GoRoute 선언 추가. path 파라미터는 `:id` 패턴 사용 |
| 새 비즈니스 로직 서비스 | `lib/services/<name>.dart` 또는 적절한 하위 도메인 폴더 | 인터페이스(추상 클래스) 분리 고려 |
| 새 피드백 서비스 | `lib/services/feedback/<name>_service.dart` | `FeedbackController`에 연결 |
| 새 OS 통합 | `lib/services/os/<name>.dart` | `TimerOsBridge`를 통해 타이머 이벤트와 연결 |
| 새 커스텀 위젯 | `lib/widgets/<name>.dart` | 2곳 이상 재사용 시. 1곳에만 쓰이면 해당 페이지 파일 내 private 위젯으로 |
| 새 Riverpod provider | `lib/providers/<domain>_provider.dart` | 기존 파일에 묶을 수 있으면 추가, 책임이 다르면 신규 파일 |
| 새 단위 테스트 | `test/<lib/ 미러 경로>/<name>_test.dart` | `lib/services/timer/timer_engine.dart` → `test/services/timer/timer_engine_test.dart` |
| 1회용 스크립트 | `tool/<name>.dart` | `analysis_options.yaml`의 `analyzer.exclude: ['tool/**']`에 의해 분석 제외됨 |

---

## 6. 핵심 Class ↔ File Lookup

| 클래스 / 식별자 | 파일 경로 |
|----------------|-----------|
| `Routine` | `lib/models/routine.dart` |
| `ExerciseItem` | `lib/models/exercise_item.dart` |
| `ExerciseType` | `lib/models/exercise_item.dart` |
| `History` | `lib/models/history.dart` |
| `FeedbackPreferences` | `lib/models/feedback_preferences.dart` |
| `DatabaseService` | `lib/services/database_service.dart` |
| `TimerEngine` | `lib/services/timer/timer_engine.dart` |
| `TimerSnapshot` | `lib/services/timer/timer_state.dart` |
| `TimerState` | `lib/services/timer/timer_state.dart` |
| `TimerPhase` | `lib/services/timer/timer_state.dart` |
| `TimerEvent` (sealed) | `lib/services/timer/timer_event.dart` |
| `PhaseStarted` | `lib/services/timer/timer_event.dart` |
| `PhaseEndingSoon` | `lib/services/timer/timer_event.dart` |
| `PhaseEnded` | `lib/services/timer/timer_event.dart` |
| `RoutineCompleted` | `lib/services/timer/timer_event.dart` |
| `Clock` | `lib/services/timer/clock.dart` |
| `FakeClock` | `lib/services/timer/clock.dart` |
| `TtsService` | `lib/services/feedback/tts_service.dart` |
| `AudioFeedbackService` | `lib/services/feedback/audio_feedback_service.dart` |
| `HapticService` | `lib/services/feedback/haptic_service.dart` |
| `AudioSessionConfigurator` | `lib/services/feedback/audio_session_configurator.dart` |
| `FeedbackController` | `lib/services/feedback/feedback_controller.dart` |
| `WakelockManager` | `lib/services/os/wakelock_manager.dart` |
| `AppLifecycleObserver` | `lib/services/os/app_lifecycle_observer.dart` |
| `ForegroundServiceController` | `lib/services/os/foreground_service_controller.dart` |
| `NotificationThrottler` | `lib/services/os/notification_throttler.dart` |
| `TimerOsBridge` | `lib/services/os/timer_os_bridge.dart` |
| `PlatformInfo` | `lib/services/os/platform_info.dart` |
| `HomePage` | `lib/pages/home_page.dart` |
| `RoutineEditPage` | `lib/pages/routine_edit_page.dart` |
| `TimerRunPage` | `lib/pages/timer_run_page.dart` |
| `CompletePage` | `lib/pages/complete_page.dart` |
| `HistoryPage` | `lib/pages/history_page.dart` |
| `CircularProgressPainter` | `lib/widgets/circular_progress_painter.dart` |
| `appRouter` | `lib/routing/app_router.dart` |
| `AppTheme` | `lib/theme/app_theme.dart` |
| `FixedTextStyles` | `lib/theme/fixed_text_styles.dart` |
| `databaseServiceProvider` | `lib/providers/database_provider.dart` |
| `refreshableRoutinesProvider` | `lib/providers/home_provider.dart` |
| `allRoutinesProvider` | `lib/providers/home_provider.dart` |
| `routinesRefreshProvider` | `lib/providers/home_provider.dart` |
| `RoutineEditNotifier` | `lib/providers/routine_edit_provider.dart` |
| `routineEditProvider` | `lib/providers/routine_edit_provider.dart` |
| `TimerEngineNotifier` | `lib/providers/timer_engine_provider.dart` |
| `timerEngineProvider` | `lib/providers/timer_engine_provider.dart` |
| `RoutineWithItems` | `lib/providers/timer_engine_provider.dart` |
| `feedbackControllerProvider` | `lib/providers/feedback_provider.dart` |
| `osProvider` | `lib/providers/os_provider.dart` |

---

## 7. 변경 시 주의사항

- **CI 검증**: `flutter analyze --no-fatal-infos` 0 errors / 0 warnings + `flutter test` 통과가 PR 머지 조건.
- **tool/ 스크립트**: `analysis_options.yaml`에서 `analyzer.exclude: ['tool/**']`로 제외됨. 1회용 스크립트는 `tool/`에 위치시킬 것.
- **Surgical change 원칙** (CLAUDE.md §3): 한 PR에서 한 책임만. 무관한 lint/스타일 동시 정리 금지 (별도 PR).
- **models 직접 수정**: `fromMap` / `toMap` 변경 시 DB 마이그레이션 또는 `onCreate` 수정이 필요할 수 있음.
- **브랜치 전략**: feature → develop PR. `main`에 직접 push 금지. 상세는 `docs/guidelines/BRANCH_STRATEGY.md` 참조.
