# PRD: Desktop Runtime Compatibility (Simple Home Workout Timer)

- **Feature**: `desktop-runtime-compat`
- **Workflow ID**: `9616148e-c027-4ade-bc80-8c06876611b1`
- **Version**: v1.0
- **Date**: 2026-05-04
- **Branch**: `feature/desktop-runtime-compat` (base: `develop`)

---

## 1. Overview

Windows 데스크톱에서 앱을 실행하면 HomePage 진입 직후 **"데이터를 불러오지 못했습니다. 다시 시도하세요."** 에러 화면이 뜨고 진행이 막힌다. 빌드는 성공하지만 런타임에서 `sqflite` 플러그인이 데스크톱 native 구현이 없어 `getAllRoutines()` 호출이 실패하기 때문이다.

이번 PR은 다음을 처리한다:

1. **(Blocking) `sqflite` 데스크톱 초기화** — `sqflite_common_ffi`로 `databaseFactory`를 교체하여 Windows/Linux/macOS에서 DB가 동작하도록 수정.
2. **(Cleanup) 미사용 의존성 제거** — `flutter_local_notifications`가 `pubspec.yaml`에 있지만 코드에서 import 0회. 삭제하여 빌드 시간/패키지 크기 감소.
3. **(Verification) 데스크톱 전반 점검** — 사전 감사로 vibration / audio_session / flutter_foreground_task / wakelock_plus / just_audio / flutter_tts는 모두 try-catch + 플랫폼 가드가 적용돼 있어 추가 코드 변경 불필요. 본 PR에서는 **Windows 실행 후 핵심 기능 정상 동작 확인**까지만 검증 항목으로 명시.

기존 Android/iOS 동작에는 **영향 없음** (변경은 데스크톱 분기 한정).

## 2. Goals

| ID | Goal | Verifiable Criterion |
|---|---|---|
| G1 | Windows에서 HomePage 정상 로드 | 앱 실행 시 빈 루틴 리스트 또는 기존 루틴 표시, 에러 화면 없음 |
| G2 | Windows에서 루틴 CRUD 동작 | 신규 루틴 생성 → 저장 → 재실행 후에도 영구 저장 확인 |
| G3 | Android/iOS 회귀 없음 | `flutter test` 100% 통과, 기존 DB 동작 변경 없음 |
| G4 | 미사용 의존성 정리 | `pubspec.yaml`에 사용처 없는 패키지 제거 |
| G5 | analyzer 경고 0 | `flutter analyze` errors 0, warnings 0 |

## 3. User Stories

- **US1 (개발자, Windows에서 개발)**: `flutter run -d windows`로 앱을 띄워 코드 변경을 즉시 검증할 수 있어야 한다 (현재는 첫 화면에서 에러로 막힘).
- **US2 (사용자, 데스크톱)**: 데스크톱 환경에서도 모바일과 동일하게 루틴 생성/실행/히스토리 조회가 가능해야 한다.
- **US3 (개발자, 모바일)**: 데스크톱 지원 추가가 모바일 빌드/동작에 영향을 주지 않아야 한다.

## 4. Functional Requirements

### F1. sqflite 데스크톱 초기화

**파일**: `lib/main.dart`

`WidgetsFlutterBinding.ensureInitialized()` 직후, 그리고 다른 어떤 DB 호출보다 먼저, 데스크톱 플랫폼에서 `sqflite`의 `databaseFactory`를 FFI 구현으로 교체.

조건:
- `kIsWeb == false` && (`Platform.isWindows` || `Platform.isLinux` || `Platform.isMacOS`)
- 모바일(Android/iOS) 분기에는 어떤 코드도 실행되지 않아야 함 (조건부 import 또는 런타임 가드)
- 초기화 실패는 try-catch로 보호하되, 실패 시 사용자에게 보이는 에러 처리는 기존 HomePage `AsyncError` 경로 그대로 사용 (별도 UI 추가 없음)

### F2. 의존성 정리

**파일**: `pubspec.yaml`

1. `sqflite_common_ffi: ^2.3.0`을 `dev_dependencies` → `dependencies`로 이동.
   - 테스트 코드(`test/services/database_service_test.dart`)는 영향 없음 (dependencies에 있어도 dev에서 import 가능).
2. `flutter_local_notifications: ^17.2.2` 제거.
   - 사용처: 코드에서 import 0회 확인 (Phase 4에서 `flutter_foreground_task`로 일원화하면서 잔여로 추정).
   - 향후 다시 필요해지면 별도 PR에서 재추가.

### F3. (검증) 데스크톱 핵심 시나리오 통과

**Verification 단계에서만 수행, 코드 변경 없음.**

수동 체크리스트 (`flutter run -d windows` 후):
- [ ] HomePage 진입, 루틴 리스트 정상 표시 (빈 상태든 데이터 있는 상태든)
- [ ] 신규 루틴 생성 → 저장 → 앱 재시작 후 영구 저장 확인
- [ ] 루틴 실행 → prep/work/rest 단계 진행 (TTS 음성, 비프음, 진동은 데스크톱에서 무음/no-op이어도 무방)
- [ ] 히스토리 페이지 진입 정상

## 5. Non-Functional Requirements

| ID | NFR | 측정 |
|---|---|---|
| N1 | Android/iOS 빌드/동작 회귀 0 | 기존 단위 테스트 통과 |
| N2 | 데스크톱 분기 코드 격리 | 모바일 코드 경로에 데스크톱 전용 import가 노출되지 않을 것 (조건부 import 또는 런타임 가드) |
| N3 | analyzer / lint 경고 추가 0 | `flutter analyze` 변동 없음 |
| N4 | DB 스키마 변경 없음 | 기존 사용자 데이터 마이그레이션 불필요 |

## 6. Out of Scope

- **Linux/macOS 실기 검증** — `sqflite_common_ffi`가 동일 코드 경로로 동작하긴 하나, 실제 검증은 Windows에서만 진행. (회귀 발견 시 별도 PR.)
- **just_audio / flutter_tts 데스크톱 동작 보장** — 현재 try-catch로 이미 안전한 실패 처리 적용됨. Windows에서 음성/오디오 실제 출력 여부는 본 PR 범위 외 (필요 시 별도 PR에서 다룸).
- **데스크톱 전용 UI 최적화** — 키보드 단축키, 윈도우 크기 응답성 개선 등은 별도 PR.
- **flutter_foreground_task 데스크톱 대체** — Android 전용으로 의도된 동작 유지 (백그라운드 timer drift 보정은 데스크톱에서 미적용).

## 7. Revision History

| Version | Date | Changes |
|---|---|---|
| v1.0 | 2026-05-04 | 초안 작성 |
