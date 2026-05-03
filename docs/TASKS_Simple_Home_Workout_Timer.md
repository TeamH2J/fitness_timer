# 📋 작업 목록: 심플 홈트 타이머

> 출처: `docs/TRD_Simple_Home_Workout_Timer.md`
> 형식: Phase별 체크리스트. 각 항목 옆 `(TRD §x.y)`로 출처 추적. 각 Phase 끝 `verify` 줄로 완료 판정 기준 명시 (CLAUDE.md §4).
> 진행 원칙: Phase는 **순차 의존**. 앞 Phase가 verify 통과 전까지 다음 Phase 진입 금지.

---

## Phase 0. 프로젝트 부트스트랩 (TRD §1)

- [ ] `flutter create` 로 프로젝트 스캐폴딩 (org 도메인 / 패키지명 결정 후 실행)
- [ ] 최소 지원 버전 설정 — iOS 16.0+, Android API 26+ (TRD §1)
- [ ] `pubspec.yaml` 핵심 의존성 추가 (Phase 0 진입 시 후보 재확정)
  - 상태관리: `flutter_riverpod` (TRD §1 후보 중)
  - 로컬 DB: `sqflite` + `path_provider` (TRD §1)
  - 화면 유지: `wakelock_plus`
  - 진동: `vibration`
  - TTS: `flutter_tts`
  - 오디오 덕킹/재생: `audio_session` + `just_audio`
  - 알림/포그라운드: `flutter_local_notifications`, `flutter_foreground_task` (Android)
- [ ] 폴더 구조 생성 — `lib/{models, providers, services, pages, widgets, utils, theme}`
- [ ] 기본 다크 테마 + 고대비 색상 정의 (TRD §4)
- [ ] 대형 숫자 전용 고정 텍스트 스타일 (시스템 textScale 무시) (TRD §4)
- [ ] (옵션) l10n 셋업 — `app_ko.arb`, `app_en.arb`
- **verify**: `flutter analyze` 0 issues + `flutter run` 빈 다크 화면 정상 부팅

---

## Phase 1. 로컬 DB 스키마 & 서비스 (TRD §3)

- [ ] `Routine` 모델 — `id`(UUID), `title`, `prep_time`, `cooldown_time`, `total_cycles`
- [ ] `ExerciseItem` 모델 — `id`(UUID), `routine_id`(FK), `order_index`, `type`(WORK_TIME/WORK_REPS/REST), `duration`, `target_reps`(nullable), `name`
- [ ] `History` 모델 — `id`(UUID), `routine_id`(FK), `completed_at`(timestamp)
- [ ] `DatabaseService` — DB open / 마이그레이션 v1 / Routine·ExerciseItem CRUD (트랜잭션 묶음)
- [ ] History insert 헬퍼 (루틴 완료 시 자동 호출)
- [ ] FK cascade 설정 (Routine 삭제 시 ExerciseItem·History 정리)
- **verify**: 단위 테스트 — Routine + 다수 ExerciseItem round-trip, FK cascade 동작

---

## Phase 2. 타이머 엔진 ⭐ Core (TRD §2.1)

- [ ] 상태 머신 `TimerState` — Idle / Running / Paused / Completed
- [ ] 흐름 컨트롤러 — Countdown(준비) → (Work ↔ Rest) × `total_cycles` → Cooldown(마무리)
- [ ] 절대 시간 기준 측정 — `targetAt = now + remaining` 저장 후 `targetAt - now`로 산출 (drift 방지) (TRD §2.1)
- [ ] Pause 처리 — `remaining` 스냅샷 / Resume 시 `targetAt` 재계산
- [ ] Reps 모드 — 내부는 `duration` 기반, UI 레이어로 `target_reps` 메타데이터 전달 (TRD §2.1)
- [ ] Phase 전환 이벤트 스트림 (UI/오디오/햅틱이 구독)
- [ ] 종료 3초 전 사전 알림 이벤트 발행
- **verify**: 단위 테스트 — (1) 백그라운드 5초 시뮬레이션 후 잔여시간 정확, (2) Pause→Resume 합산 정확, (3) Reps 모드 UI 메타데이터 전달

---

## Phase 3. 오디오 & 햅틱 피드백 (TRD §2.2)

- [ ] `TtsService` — 앱 부팅 시 pre-warm으로 latency 최소화 (TRD §2.2)
- [ ] Phase 진입 시 운동명 발화
- [ ] 카운트다운 음성 (3-2-1) 또는 비프음 (TRD §2.2)
- [ ] 비프음 에셋 (시작/종료 3초 전) — 짧은 wav를 `assets/audio/` 에 추가
- [ ] 진동 패턴
  - iOS: `CoreHaptics` (Cupertino 햅틱) (TRD §2.2)
  - Android: `VibrationEffect` 기반 패턴 (TRD §2.2)
- [ ] 오디오 덕킹
  - iOS: `AVAudioSession.duckOthers` 활성화 (TRD §2.2)
  - Android: `AudioManager.requestAudioFocus` + `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` (TRD §2.2)
- **verify**: 백그라운드 음악 재생 중 운동 시작 시 음악 볼륨 자동 감소 → 운동 종료 후 복원

---

## Phase 4. OS 통합 / 백그라운드 (TRD §2.3, §5)

- [ ] 화면 켜짐 유지 — Running 시 wakelock ON / 그 외 OFF (TRD §2.3)
- [ ] **iOS** — Live Activities + Dynamic Island (ActivityKit) 로 잠금화면 실시간 표시 (TRD §2.3)
  - 네이티브 Widget Extension (Swift) 추가 필요 — 별도 의사결정 항목
- [ ] **Android** — Foreground Service + Ongoing Notification (TRD §2.3)
- [ ] 앱 라이프사이클 훅 — 백그라운드 진입 시 UI 렌더링 중단, 복귀 시 상태 복구 (TRD §5)
- [ ] 알림창 업데이트 주기 최적화 (1초 미만 갱신 금지 등) (TRD §5)
- **verify**: 잠금화면에서 남은 시간 갱신 / 백그라운드 5분 후 복귀 시 drift 0초

---

## Phase 5. UI / UX (TRD §4)

### 5.1 홈 / 편집 / 히스토리
- [ ] 홈 화면 — 루틴 리스트 + 신규 추가 FAB
- [ ] 루틴 편집 화면 — ExerciseItem CRUD + drag-to-reorder
- [ ] 히스토리 화면 — 간단 리스트 (날짜/루틴명)
- [ ] 완료 화면 — History 자동 기록 + "다시 하기" / "홈으로"

### 5.2 타이머 실행 화면 (TRD §4 시인성·터치 제어·렌더링)
- [ ] 다크 모드 기본 + 고대비 색상
- [ ] 고정 대형 숫자 폰트 (textScale 무시)
- [ ] 원형 프로그레스 바 — `CustomPaint` + `Ticker`로 60fps 렌더 (TRD §4)
- [ ] 전체 화면 투명 `GestureDetector` 최상단 배치 → `togglePlayPause()` (TRD §4)
- [ ] 현재 운동명 / 현재 사이클 (n / total) / 다음 항목 미리보기 표시
- [ ] Reps 모드일 경우 목표 횟수 노출 (TRD §2.1)
- **verify**: 실기기 — (1) 화면 어디 탭이든 토글 동작, (2) 60fps 유지, (3) OS 글자 크기 변경해도 숫자 크기 고정

---

## Phase 6. 비기능 요구사항 (TRD §5)

- [ ] 백그라운드 진입 시 setState/Animation 정지 검증 (배터리)
- [ ] 네트워크 호출 0건 검증 — `http`/`dio` 등 미포함 또는 패킷 캡처
- [ ] 30분 실행 시 배터리 소모율 기록
- [ ] **v1.0 제외 범위 준수** — 클라우드 동기화 / 세트 건너뛰기 / 스마트워치 / 통계 분석 placeholder 금지 (TRD §5)
- **verify**: 릴리즈 빌드로 배터리·네트워크 점검 통과

---

## Phase 7. QA & 정리

- [ ] `flutter analyze --no-fatal-infos` 0 errors / 0 warnings (CLAUDE.md §7)
- [ ] 핵심 단위/위젯 테스트 — Timer Engine 우선 (drift, pause/resume, phase 전환)
- [ ] iOS/Android 실기기 E2E 시나리오 — 운동 시작 → 백그라운드 → 잠금 → 복귀 → 완료
- [ ] `docs/guidelines/CODEBASE_MAP.md` 갱신 — 현재 account_book용 → fitnessTimer용으로 교체

---

## TRD 매핑 점검표

| TRD 섹션 | 다루는 Phase |
|---|---|
| §1 시스템·기술 스택 | Phase 0 |
| §2.1 타이머 엔진 | Phase 2 |
| §2.2 오디오/햅틱 | Phase 3 |
| §2.3 백그라운드/OS | Phase 4 |
| §3 DB 스키마 | Phase 1 |
| §4 UI/UX | Phase 5 |
| §5 비기능/제외 범위 | Phase 6, Phase 4 일부 |

---

## 추후 의사결정 필요 항목 (Phase 진입 전 확정)

- 상태관리 라이브러리 — TRD는 Provider/Riverpod/BLoC 모두 후보로 둠 → Phase 0에서 1개 확정
- 로컬 DB — Sqflite vs Hive vs Realm → Phase 0에서 1개 확정
- iOS Live Activities — 1차 릴리즈 포함 vs 후속 PR로 분리 → Phase 4 진입 전 결정
