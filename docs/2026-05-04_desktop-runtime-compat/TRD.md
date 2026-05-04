# TRD: desktop-runtime-compat

- Date: 2026-05-04
- Author: TRD Agent
- Reference: PRD `.claude/outputs/PRD.md`

---

## 1. System Architecture Diagram

이 PR은 `lib/main.dart`와 `pubspec.yaml` 두 파일만 수정한다. 아키텍처 전체는 유지되며 변경 범위를 강조해 표시한다.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter App Boot                            │
│                                                                     │
│  main() async                                                       │
│  ├── WidgetsFlutterBinding.ensureInitialized()                      │
│  │                                                                  │
│  ├── [NEW] initDesktopDb()  ← 삽입 위치                             │
│  │    └── Windows/Linux/macOS: sqfliteFfiInit()                     │
│  │                           + databaseFactory = databaseFactoryFfi │
│  │        Android/iOS/Web: no-op (stub)                             │
│  │                                                                  │
│  ├── initFlutterForegroundTask()  [Android only, try-catch]         │
│  │                                                                  │
│  ├── ProviderContainer                                              │
│  │    ├── audioSessionConfiguratorProvider                          │
│  │    └── appLifecycleObserverProvider                              │
│  │                                                                  │
│  └── runApp(UncontrolledProviderScope → FitnessTimerApp)            │
│                                                                     │
│  ┌────────────┐   ┌──────────────┐   ┌──────────────────────────┐  │
│  │   Pages    │──▶│  Providers   │──▶│       Services           │  │
│  │ HomePage   │   │ (Riverpod)   │   │ DatabaseService          │  │
│  │ TimerRun   │   │ DatabaseProv │   │  ├─ desktop: FFI factory  │  │
│  │ Complete   │   │ TimerEngine  │   │  └─ mobile: native sqfl   │  │
│  │ RoutineEdit│   │ FeedbackProv │   │ TimerEngine               │  │
│  │ History    │   │ OsProvider   │   │ FeedbackController        │  │
│  └────────────┘   └──────────────┘   └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  sqflite DB (fitness_timer.db)   │
│  Android / iOS : native plugin   │
│  Windows / Linux / macOS : FFI   │
└──────────────────────────────────┘
```

**변경 파일 요약:**

```
lib/main.dart                          ← initDesktopDb() 호출 1줄 + import 1줄 추가
lib/utils/desktop_db_init.dart         ← 신규 (조건부 export 진입점)
lib/utils/desktop_db_init_stub.dart    ← 신규 (Android/iOS/Web no-op)
lib/utils/desktop_db_init_desktop.dart ← 신규 (Windows/Linux/macOS FFI 실구현)
pubspec.yaml                           ← sqflite_common_ffi: dev → dependencies 이동
                                          flutter_local_notifications 제거
```

---

## 2. Tech Stack & Dependencies

| Item | Choice | Reason |
|------|--------|--------|
| Language | Dart 3.x+ (SDK ^3.11.4) | 기존 유지 |
| UI Framework | Flutter 3.x+ | 기존 유지 |
| State Management | flutter_riverpod ^2.5.1 | 기존 유지 |
| Local DB (mobile) | sqflite ^2.3.3 | Android/iOS native plugin; 변경 없음 |
| Local DB (desktop) | sqflite_common_ffi ^2.3.0 | Windows/Linux/macOS FFI 구현; **dev_dependencies → dependencies 이동** |
| DB path helper | path_provider ^2.1.4, path ^1.9.0 | 기존 유지 |
| ID generation | uuid ^4.5.0 | 기존 유지 |
| Routing | go_router ^14.6.0 | 기존 유지 |
| Audio / TTS / Haptic | just_audio, audio_session, flutter_tts, vibration | 기존 유지; 데스크톱 try-catch 이미 적용됨 |
| Foreground Service | flutter_foreground_task ^8.10.0 | 기존 유지 (Android 전용) |
| **제거** | ~~flutter_local_notifications ^17.2.2~~ | 코드 전체에서 import 0회 확인; 불필요한 의존성 제거 |
| Localization | flutter_localizations SDK + intl | 기존 유지 |
| Dev: Fake async | fake_async ^1.3.1 | 기존 유지 |
| Dev: Lints | flutter_lints ^6.0.0 | 기존 유지 |

### pubspec.yaml 논리적 diff

```yaml
 dependencies:
   ...
+  sqflite_common_ffi: ^2.3.0      # moved from dev_dependencies
-  flutter_local_notifications: ^17.2.2  # removed — 0 imports in codebase

 dev_dependencies:
-  sqflite_common_ffi: ^2.3.0      # moved to dependencies
```

---

## 3. Module / Component Specification

### initDesktopDb — 조건부 Desktop FFI 초기화 (신규)

- Role: 앱 부팅 시 데스크톱 플랫폼에서만 sqflite 전역 `databaseFactory`를 FFI 구현으로 교체
- Responsibilities:
  - `WidgetsFlutterBinding.ensureInitialized()` 직후, `ProviderContainer` 생성 전에 동기 실행
  - Windows/Linux/macOS: `sqfliteFfiInit()` 호출 후 `databaseFactory = databaseFactoryFfi` 설정
  - Android/iOS/Web: no-op (stub 함수가 선택됨)
- Interface: `void initDesktopDb()` — 동기 함수, 반환값 없음

**파일 구조 (조건부 import 3파일 패턴):**

```
lib/utils/desktop_db_init.dart          — 조건부 export 진입점
lib/utils/desktop_db_init_stub.dart     — no-op stub (non-FFI 플랫폼용)
lib/utils/desktop_db_init_desktop.dart  — 실구현 (FFI 지원 플랫폼용)
```

**조건부 import vs 런타임 가드 선택 근거:**

| 방식 | 장점 | 단점 |
|------|------|------|
| 조건부 import (채택) | `sqflite_common_ffi` FFI 심볼이 stub 경로를 타는 플랫폼 번들에 포함되지 않음; PRD N2 완전 충족 | stub/impl/진입점 파일 3개 필요 |
| 런타임 가드 (`kIsWeb` + `Platform.is*`) | 단일 파일로 간단 | `sqflite_common_ffi`가 모든 플랫폼 번들에 링크됨; iOS/Android 앱 크기 증가 |

조건부 import를 채택한다. `dart.library.html` 존재 여부로 web/non-web을 분기하고, non-web 구현 파일 내부에서 `Platform.isWindows || Platform.isLinux || Platform.isMacOS` 런타임 가드를 추가로 사용한다. 이 이중 가드가 필요한 이유는 `dart.library.ffi`만으로는 Android/iOS(native FFI 지원)도 impl 파일을 선택하기 때문이다.

### main.dart — 삽입 위치 명세

현재 `main.dart` 라인 기준 정확한 삽입 위치:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();   // 기존 line 11

  initDesktopDb();   // ← 여기에 삽입 (line 11과 line 14 사이)
                     //   ProviderContainer 생성(line 22) 보다 반드시 먼저 실행
                     //   initFlutterForegroundTask() 전후 모두 허용되나
                     //   "모든 platform init의 첫 블록"으로 ensureInitialized() 직후에 위치

  try {
    initFlutterForegroundTask();               // 기존 line 16
  } catch (_) {}

  try {
    final container = ProviderContainer();     // 기존 line 22 ← DB에 닿는 첫 provider
```

`DatabaseService._initDb()`는 `ProviderContainer`가 `databaseProvider`를 처음 읽는 시점(HomePage 진입 시)에 호출되므로, `ProviderContainer` 생성 전에 `databaseFactory`가 설정되어 있으면 충분하다. 그러나 미래 코드 변경에서 `ProviderContainer` 생성 직후 DB를 읽는 provider가 추가될 수 있으므로 가능한 앞쪽(ensureInitialized 바로 다음)에 고정한다.

### DatabaseService (`lib/services/database_service.dart`) — 변경 없음

- `{String? dbPath}` 생성자 주입 패턴 유지
- `_dbPath == null`이면 `getApplicationDocumentsDirectory()` 경로 사용 (Windows 동작 정상)
- 전역 `databaseFactory`가 FFI로 교체된 상태에서 `openDatabase()`를 호출하면 자동으로 FFI 구현이 사용됨

---

## 4. Data Model / Schema

스키마 변경 없음. 기존 3개 테이블 그대로 유지.

Windows에서 DB 파일 경로: `path_provider`의 `getApplicationDocumentsDirectory()`가 반환하는 경로 (`%USERPROFILE%\Documents` 또는 앱 로컬 데이터 경로). FFI 팩토리는 이 경로를 그대로 수용한다.

### Routine (DB table: `routines`)
| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| title | TEXT | NOT NULL | 루틴 이름 |
| prep_time | INTEGER | NOT NULL DEFAULT 0 | 준비 시간 (초) |
| cooldown_time | INTEGER | NOT NULL DEFAULT 0 | 쿨다운 시간 (초) |
| total_cycles | INTEGER | NOT NULL DEFAULT 1 | 반복 횟수 |

### ExerciseItem (DB table: `exercise_items`)
| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| routine_id | TEXT | NOT NULL, FK → routines.id ON DELETE CASCADE | 소속 루틴 |
| order_index | INTEGER | NOT NULL | 정렬 순서 |
| type | TEXT | NOT NULL, CHECK IN ('WORK_TIME','WORK_REPS','REST') | 운동 타입 |
| duration | INTEGER | NOT NULL DEFAULT 0 | 시간(초) |
| target_reps | INTEGER | nullable | 목표 반복 횟수 (WORK_REPS 전용) |
| name | TEXT | NOT NULL | 운동 이름 |

### History (DB table: `histories`)
| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| id | TEXT | PRIMARY KEY | UUID v4 |
| routine_id | TEXT | NOT NULL, FK → routines.id ON DELETE CASCADE | 완료한 루틴 |
| completed_at | TEXT | NOT NULL | ISO 8601 UTC datetime |

### DB 인덱스
| Index | Table | Column | Purpose |
|-------|-------|--------|---------|
| idx_exercise_items_routine_id | exercise_items | routine_id | 루틴별 항목 조회 최적화 |
| idx_histories_routine_id | histories | routine_id | 루틴별 히스토리 조회 최적화 |

---

## 5. API / Interface Specification

이 앱은 백엔드 HTTP API가 없는 오프라인 전용이다. 이번 PR에서 추가되는 유일한 인터페이스는 내부 init 함수다.

### initDesktopDb()

| 항목 | 내용 |
|------|------|
| 진입점 | `lib/utils/desktop_db_init.dart` |
| 시그니처 | `void initDesktopDb()` |
| 호출 위치 | `main()` 내 `WidgetsFlutterBinding.ensureInitialized()` 직후 |
| 반환 | void (동기; `sqfliteFfiInit()`은 동기 함수) |
| 플랫폼 동작 | Web: stub no-op / Android/iOS: stub no-op / Windows/Linux/macOS: FFI 등록 |
| 실패 처리 | 예외가 `main()` 밖으로 전파 → 기존 `AsyncError` → HomePage 에러 화면 |

### 각 파일의 코드 명세

**`lib/utils/desktop_db_init.dart` (조건부 export):**
```dart
export 'desktop_db_init_stub.dart'
    if (dart.library.html) 'desktop_db_init_stub.dart'
    if (dart.library.ffi) 'desktop_db_init_desktop.dart';
```

**`lib/utils/desktop_db_init_stub.dart`:**
```dart
void initDesktopDb() {}
```

**`lib/utils/desktop_db_init_desktop.dart`:**
```dart
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDesktopDb() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
```

`dart.library.html` 조건이 먼저 평가되어 web에서는 stub이 선택된다. non-web native 환경에서는 `dart.library.ffi`로 desktop impl이 선택되며, impl 내부 `Platform` 가드가 Android/iOS에서 FFI 호출을 차단한다. 이 이중 가드로 PRD N2(데스크톱 분기 코드 격리)를 완전히 충족한다.

**`lib/main.dart` 추가 내용 (2줄):**
```dart
import 'utils/desktop_db_init.dart';   // 상단 import에 추가

// main() 내 ensureInitialized() 직후:
initDesktopDb();
```

### DatabaseService 인터페이스 (변경 없음)

`getAllRoutines()`, `getRoutine(id)`, `getExerciseItems(routineId)`, `upsertRoutineWithItems(routine, items)`, `deleteRoutine(id)`, `insertHistory(routineId)`, `getHistories({limit})` — 시그니처 변경 없음.

---

## 6. Error Handling & Exception Flow

| Scenario | Handling | User Message |
|----------|----------|--------------|
| `sqfliteFfiInit()` 실패 (예: sqlite3.dll 누락) | 예외가 `main()`으로 전파; fallback `runApp(ProviderScope(...))` 실행; 홈 화면에서 DB 접근 시 AsyncError | "데이터를 불러오지 못했습니다. 다시 시도하세요." (기존 에러 UI 재사용, 별도 UI 추가 없음) |
| `databaseFactory` 설정 후 `openDatabase()` 실패 | `DatabaseService._initDb()` 예외 전파 → Provider AsyncError | 기존 에러 화면 그대로 |
| Android/iOS에서 `desktop_db_init_desktop.dart` 선택될 경우 | 내부 `Platform.isWindows || isLinux || isMacOS` 가드가 false → no-op; 기존 native sqflite 동작 유지 | 사용자에게 노출 안함 |
| Web 빌드에서 `dart.library.html` 조건으로 stub 선택 | no-op; web 경로는 sqflite를 사용하지 않음 | 해당 없음 |
| `flutter_local_notifications` 제거 후 잔여 참조 | import 0회 확인 완료; pubspec 제거만으로 충분; `flutter analyze`로 검증 | 해당 없음 |
| `getApplicationDocumentsDirectory()` 실패 (Windows) | `DatabaseService._initDb()` 예외 전파 → 기존 AsyncError 경로 | 기존 에러 화면 |

---

## 7. Test Strategy

### Unit Tests

**기존 테스트 회귀 위험 분석 — `test/services/database_service_test.dart`:**

현재 테스트의 `setUpAll`은 직접 `sqfliteFfiInit()` + `databaseFactory = databaseFactoryFfi`를 호출하고, `DatabaseService(dbPath: 'file:uuid?mode=memory&cache=shared')` 주입 패턴으로 실행된다. 이 구조는 프로덕션 `initDesktopDb()` 호출과 완전히 독립적이다.

- `sqflite_common_ffi`가 `dev_dependencies`에 있을 때: 테스트에서 import 가능 — 현재 동작
- `sqflite_common_ffi`를 `dependencies`로 이동 후: 동일하게 import 가능 — `dependencies`의 패키지도 테스트에서 접근 가능

**결론: 테스트 영향 없음.** `dependencies` 이동은 테스트 가용성을 제거하지 않는다. `dbPath` 주입 패턴 변경도 없다.

- Target: 기존 129+ 테스트 전량 (`flutter test`)
- Coverage goal: 기존 수준 유지

신규 `initDesktopDb()`는 전역 상태를 설정하는 단순 함수이므로 독립적인 단위 테스트를 추가하지 않는다. 동작 검증은 Windows 수동 스모크 테스트로 커버한다.

### Integration Tests

- Target: `DatabaseService` — `sqflite_common_ffi` 인메모리 DB (`file:uuid?mode=memory&cache=shared`)
- 실행: `flutter test` (기존 `database_service_test.dart` 5개 + 모델 round-trip 테스트 포함)
- 테스트는 `setUpAll`에서 독립적으로 `databaseFactory`를 설정하므로 프로덕션 init 경로와 격리됨

### E2E Test Scenarios (수동 — PRD F3 체크리스트)

`flutter run -d windows` 실행 후:

| ID | 시나리오 | 기대 결과 |
|----|---------|----------|
| W1 | 앱 실행 → HomePage 진입 | 에러 화면 없음; 빈 루틴 리스트 또는 기존 루틴 표시 |
| W2 | 신규 루틴 생성 → 저장 → 앱 재시작 | 재시작 후 루틴 목록에 영구 저장 확인 |
| W3 | 루틴 실행 → prep/work/rest 단계 진행 | 단계 전환 정상; TTS/진동/비프음이 no-op이어도 크래시 없음 |
| W4 | 히스토리 페이지 진입 | 정상 표시 (완료 기록 있으면 목록, 없으면 빈 상태) |

**검증 명령어 시퀀스:**

```powershell
# 1. 정적 분석 (errors 0, warnings 0)
flutter analyze

# 2. 단위/통합 테스트 전량
flutter test

# 3. Windows 디버그 빌드
flutter build windows --debug

# 4. Windows 실행 (수동 스모크 W1~W4)
flutter run -d windows
```

---

## 8. Security Considerations

이 앱은 오프라인 전용, 네트워크 통신 없음, 계정/인증 없음이다.

| Threat | Mitigation |
|--------|------------|
| SQL Injection | 기존 `?` 바인딩 파라미터 사용 유지; FFI 팩토리 교체는 SQL 실행 레이어에 영향 없음 |
| 로컬 데이터 탈취 | Windows DB 파일은 `getApplicationDocumentsDirectory()` 경로에 저장; 파일 시스템 접근 제어는 OS 책임 |
| FFI 라이브러리 공급망 | `sqflite_common_ffi`는 sqflite 공식 생태계 패키지 (pub.dev 검증됨); `^2.3.0` semver caret으로 고정 |
| 모바일 번들에 FFI 심볼 노출 | 조건부 import + Platform 이중 가드로 Android/iOS에서 FFI 코드 미실행; stub 경로로 tree-shaking 동작 |
| XSS | 웹 표면 없음; 순수 native Flutter 렌더링 — 해당 없음 |
| Auth bypass | 계정/인증 없음 (v1.0 scope 외) — 해당 없음 |
| 의존성 공급망 (제거 패키지) | `flutter_local_notifications` 제거 시 해당 패키지의 취약점 노출 면적 감소 |
| NetworkDependencyGuard CI | `sqflite_common_ffi`는 네트워크 패키지가 아님; dependencies 이동 후 CI 스캔 통과 예상 |

---

## 부록: 롤백 절차

변경 파일이 최소화되어 있어 롤백은 단순하다.

1. `pubspec.yaml`: `sqflite_common_ffi`를 `dependencies`에서 `dev_dependencies`로 복원; `flutter_local_notifications: ^17.2.2` 재추가
2. `lib/main.dart`: `initDesktopDb()` 호출 1줄 및 import 1줄 제거
3. `lib/utils/desktop_db_init.dart`, `desktop_db_init_stub.dart`, `desktop_db_init_desktop.dart` 3개 파일 삭제
4. `flutter pub get` 실행
5. `flutter analyze` + `flutter test`로 원상 복구 확인
