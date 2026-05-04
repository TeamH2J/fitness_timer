# PRD — Timer Ring Color by Phase

| Field | Value |
|-------|-------|
| Feature | timer-phase-color |
| Workflow ID | 8a249c73-cf3c-474a-ae0c-3a9d67c50b89 |
| Version | v1.0 |
| Author | main session (co-feature mode) |
| Date | 2026-05-04 |

---

## 1. Overview

타이머 실행 화면(`TimerRunPage`)의 원형 progress ring은 현재 phase와 무관하게 항상 단일 색(`colorScheme.primary` = `#FF5252` 빨강)으로 그려진다. 사용자는 어느 phase에 있는지 글자(prep/work/rest/cooldown 라벨)를 읽어야만 알 수 있어 운동 중 한눈에 식별이 어렵다.

이 기능은 **각 phase에 고유한 색상을 부여**해서 ring 색만 봐도 현재 상태(준비/운동/휴식/쿨다운)를 즉시 인지할 수 있도록 한다.

## 2. Goals

- **G1.** 타이머 ring의 foreground 색이 현재 `TimerPhase`에 따라 4가지 중 하나로 그려진다.
- **G2.** phase 전환 시 색이 추가 입력·애니메이션 없이 다음 frame에 즉시 반영된다 (기존 reactive 구독에 그대로 묻어가는 형태).
- **G3.** 변경 전후로 progress 진행 로직, 카운트다운 숫자, "Next" 미리보기 등 다른 UI 요소가 영향을 받지 않는다 (regression-free).

## 3. User Stories

- **US1.** 운동 중인 사용자로서, ring이 빨강이면 운동, 초록이면 휴식임을 즉시 알아 동작을 전환할 수 있다.
- **US2.** 처음 앱을 켠 사용자로서, prep 단계에서 amber ring을 보고 "곧 시작된다"는 신호를 받는다.
- **US3.** 마지막 cycle 후 cooldown에 진입한 사용자로서, ring이 cyan으로 바뀌어 마무리 단계임을 인지한다.

## 4. Functional Requirements

### FR1. Phase → Color 매핑

| Phase | Hex | 명칭 | 의도 |
|-------|-----|------|------|
| `prep` | `#FFB300` | Amber | 준비 — 시작 직전 |
| `work` | `#FF5252` | Red | 운동 — 강도/에너지 (현재 색 유지) |
| `rest` | `#4CAF50` | Green | 휴식 — 회복 |
| `cooldown` | `#26C6DA` | Cyan | 쿨다운 — 마무리 |

### FR2. Fallback 동작

- `TimerSnapshot.phase == null` 인 짧은 순간(idle / completed)에는 fallback 으로 Work red(`#FF5252`)를 사용한다 — 화면에 보일 가능성이 거의 없으나 안전한 기본값.

### FR3. 적용 위치

- `lib/pages/timer_run_page.dart`의 `_TimerRunView` 위젯이 그리는 `CircularProgressPainter.foreground` 인자(현재 line 233 `colorScheme.primary`)만 phase 기반 매핑으로 교체한다.
- 다른 위젯·페이지는 변경하지 않는다.

### FR4. State 노출

- `TimerSnapshot.phase`는 이미 Riverpod `timerEngineProvider`로 reactive하게 노출되고 있다 → 신규 provider/state 없음.

## 5. Non-Functional Requirements

- **NF1. 호환성.** Light/Dark 테마 분기 없음 (앱이 dark-only이므로). 기존 `AppTheme.dark`도 변경 없음.
- **NF2. 성능.** 매핑은 O(1) switch — 60fps `AnimatedBuilder` rebuild에 영향 없음.
- **NF3. 정적 분석.** `flutter analyze` 0 errors / 0 warnings (CLAUDE.md §7).
- **NF4. 접근성.** 색상에만 의존하지 않음 — phase 라벨(`_phaseLabel`)은 그대로 표시되어 색약 사용자도 텍스트로 식별 가능.
- **NF5. 코드 품질.** 매핑 helper는 `_phaseLabel`과 동일한 패턴/위치(같은 클래스의 private method)로 유지 (CLAUDE.md §3 surgical).

## 6. Out of Scope

- Light theme 추가, 시스템 테마 follow, 사용자 색상 커스터마이징.
- 다른 화면(home, complete, history) 색상 변경.
- 카운트다운 숫자, 배경, 텍스트 색상 변경.
- Phase 전환 시 색 트윈/애니메이션 (즉시 전환으로 충분).
- 다국어 처리 변경 (라벨 텍스트는 기존 그대로).
- Theme/색상 상수 파일 신설 — YAGNI (현재 한 위젯에서만 사용).

## 7. Revision History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| v1.0 | 2026-05-04 | main session | Initial draft. Palette confirmed by user via AskUserQuestion (standard fitness palette). |
