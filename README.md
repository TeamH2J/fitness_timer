# fitnessTimer — 심플 홈트 타이머 v1.0

오프라인 전용 인터벌 트레이닝 타이머 앱. 광고 없음 · 계정 없음 · 네트워크 없음.

---

## 1. 프로젝트 개요

루틴을 만들고 타이머를 실행하면 준비(prep) → 운동(work) → 휴식(rest) → 쿨다운(cooldown) 순서로 자동 진행된다.
운동 이름을 TTS로 읽어주고, 페이즈 전환 시 비프음·진동으로 알려준다.
다크 테마 전용, 모든 데이터는 기기 로컬에만 저장된다.

---

## 2. 주요 기능

- **루틴 편집** — 제목, 준비 시간, 쿨다운 시간, 반복 횟수, 항목별 이름·시간·목표 reps 설정
- **인터벌 타이머** — prep → work/rest 사이클 → cooldown 자동 전환 (250ms 정밀도)
- **TTS 음성 안내** — 운동 이름을 한국어로 읽어줌 (설정으로 on/off)
- **오디오 덕킹** — 운동 중 타 앱 음악 볼륨 자동 감소 후 복원
- **햅틱 피드백** — 페이즈 전환 시 진동
- **백그라운드 동작** — Android 포그라운드 서비스 / iOS 백그라운드 타이머 유지
- **잠금화면 알림** — 운동 중 현재 phase·잔여시간 알림 표시
- **운동 히스토리** — 완료 시 자동 기록, 히스토리 페이지에서 최신순 조회
- **Reps 모드** — 시간 기반 대신 목표 반복 횟수 표시 (시간 초과 시 자동 다음 phase)

---

## 3. 기술 스택

| 항목 | 버전 |
|------|------|
| Flutter / Dart | 3.x+ / SDK ^3.11.4 |
| 상태 관리 | flutter_riverpod ^2.5.1 |
| 로컬 DB | sqflite ^2.3.3 |
| 라우팅 | go_router ^14.6.0 |
| 오디오 | just_audio ^0.9.40 + audio_session ^0.1.21 |
| TTS | flutter_tts ^4.0.2 |
| 햅틱 | vibration ^2.0.0 |
| 화면 켜짐 유지 | wakelock_plus ^1.2.5 |
| 포그라운드 서비스 | flutter_foreground_task ^8.10.0 |
| 알림 | flutter_local_notifications ^17.2.2 |

---

## 4. 빌드 & 실행

### 사전 요구사항

- Flutter 3.x+, Dart 3.x+
- Android: Android SDK (minSdkVersion **26**)
- iOS: Xcode (iOS **16.0**+)

### 명령

```bash
# 의존성 설치
flutter pub get

# 정적 분석 (0 issues 목표)
flutter analyze --no-fatal-infos

# 테스트 실행
flutter test

# 앱 실행 (연결된 기기 선택)
flutter run
```

---

## 5. 테스트

```bash
# 전체 단위·통합 테스트
flutter test

# 특정 파일
flutter test test/services/timer/timer_engine_test.dart

# 커버리지
flutter test --coverage
```

E2E 시나리오(실기기 수동 검증): [`docs/E2E_TEST_SCENARIOS.md`](docs/E2E_TEST_SCENARIOS.md)

---

## 6. 프로젝트 구조

코드베이스 폴더 트리, 도메인 맵, 핵심 클래스 lookup:

[`docs/guidelines/CODEBASE_MAP.md`](docs/guidelines/CODEBASE_MAP.md)

---

## 7. 개발 워크플로

- 브랜치 전략: [`docs/guidelines/BRANCH_STRATEGY.md`](docs/guidelines/BRANCH_STRATEGY.md)
- 멀티 에이전트 워크플로: [`docs/guidelines/MULTI_AGENT_WORKFLOW.md`](docs/guidelines/MULTI_AGENT_WORKFLOW.md)

---

## 8. 라이센스

TBD
