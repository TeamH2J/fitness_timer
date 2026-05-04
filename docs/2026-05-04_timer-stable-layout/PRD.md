# PRD — Timer Run Page Stable Layout

| Field | Value |
|-------|-------|
| Feature | timer-stable-layout |
| Workflow ID | 6859f513-fcf8-4573-b000-66bb3ef37cfc |
| Version | v1.0 |
| Author | main session (co-feature mode) |
| Date | 2026-05-04 |

---

## 1. Overview

타이머 실행 화면(`TimerRunPage` / `_TimerRunView`)의 메인 Column은 `mainAxisAlignment: MainAxisAlignment.center` 로 세로 가운데 정렬되어 있다. 그런데 children 중 일부가 **조건부로 렌더링**되거나 **wrap에 따라 줄 수가 달라지는** 텍스트라서, 정보가 바뀔 때마다 column 총 높이가 변동 → center alignment가 다시 계산되어 다른 행이 위/아래로 밀린다. 사용자는 이 흔들림이 거슬린다고 보고했고, "텍스트 정보가 갱신되어도 행과 열이 모두 유지" 되기를 원한다.

이 기능은 **각 자식의 차지 공간을 고정**해서 phase 전환·pause 토글·텍스트 길이 변화와 무관하게 ring·라벨·다음 안내 등 모든 행의 화면상 좌표가 안정되도록 한다.

## 2. Goals

- **G1.** phase가 prep / work / rest / cooldown 사이를 전환해도 ring 중심의 화면상 (x, y) 좌표가 동일하게 유지된다.
- **G2.** pause / resume 토글 시 ring 및 그 위 텍스트들의 좌표가 흔들리지 않는다.
- **G3.** WORK_TIME ↔ WORK_REPS phase 전환 시 (`targetReps` 표시/비표시) 다른 행이 위로 밀리거나 아래로 내려오지 않는다.
- **G4.** 운동 이름·"다음" 라벨의 텍스트 폭/길이가 달라져도 세로 위치는 변하지 않는다.

## 3. User Stories

- **US1.** 운동 중인 사용자로서, ring을 응시하며 호흡·자세에 집중할 수 있다 — 정보 갱신 시마다 ring이 화면에서 들썩이지 않는다.
- **US2.** 화면을 탭해 pause를 토글하는 사용자로서, pause 아이콘이 등장/소멸할 때 카운트다운 숫자 위치가 그대로다.
- **US3.** 운동 이름이 길거나 짧은 다양한 루틴을 가진 사용자로서, 어떤 이름이든 ring 위치는 일정하다.

## 4. Functional Requirements

### FR1. 조건부 자식 슬롯 고정

다음 세 위젯을 **고정 높이 슬롯**(`SizedBox(height: X, child: ...)`)으로 감싼다. 조건이 false일 때도 슬롯의 높이는 유지하고 child만 비운다.

| 자식 | 조건 | 슬롯 높이 |
|------|------|----------|
| Reps target 텍스트 (fontSize 20) | `snapshot.targetReps != null` | 28 |
| Next item 미리보기 (fontSize 14) | `nextPhase == rest` 또는 `nextItem != null` | 20 |
| Pause indicator (`Icon(size:32) + Padding(top:16)`) | `state == TimerState.paused` | 48 |

### FR2. 가변 텍스트 행 고정

폭이 변하거나 wrap 가능성이 있는 두 텍스트도 고정 높이 + 단일 행으로 강제:

| 자식 | 슬롯 높이 | 추가 처리 |
|------|----------|-----------|
| Cycle indicator (fontSize 16) | 22 | `maxLines: 1`, `overflow: TextOverflow.ellipsis` |
| Phase name (fontSize 24) | 32 | `maxLines: 1`, `overflow: TextOverflow.ellipsis`, `textAlign: center` |

### FR3. 변경 외 영역 보존

- ring(240×240), digit 텍스트, 기존 spacer `SizedBox(height: 8/24/16/24)` 는 변경 없음.
- "다음: 휴식" 분기(PR #12)와 `_phaseName` 의 `이름(휴식)` 형식(PR #13) 동작 그대로.
- 색상 매핑(`_phaseColor`)도 그대로.

## 5. Non-Functional Requirements

- **NF1. 단순성.** 새 위젯 추출 / 컴포넌트화 없음. 같은 파일·같은 build 메서드 내 인라인 변경 (CLAUDE.md §2, §3).
- **NF2. 정적 분석.** `flutter analyze` 0 errors / 0 warnings (CLAUDE.md §7).
- **NF3. 회귀 없음.** 기존 위젯 테스트 (`test/pages/timer_run_page_color_test.dart`) 5/5 pass 유지. 기존 엔진 테스트 영향 없음.
- **NF4. 접근성.** 보이지 않는 슬롯은 child가 `null` (Visibility 의 invisible placeholder 가 아님) → semantics tree에 잡히지 않음.
- **NF5. 성능.** SizedBox 한 단계 추가만 — 60fps `AnimatedBuilder` rebuild 부담 없음.

## 6. Out of Scope

- digit 텍스트(`$remainingSeconds`) 폰트 metrics / monospace 변환 — 외곽이 240×240 고정이라 ring 위치에는 영향 없음, 사용자 불만의 원인이 아님.
- 다른 페이지(home, complete, history) 레이아웃.
- phase 전환·pause 토글 시 슬롯 페이드/슬라이드 트윈 애니메이션 — 요청은 "위치 유지", 트윈은 별개 기능.
- 신규 컴포넌트(`StableSlot`, `FixedHeightText` 등) 추출 — 단일 사용처라 YAGNI.
- 가로 폭 안정화를 위한 좌우 패딩 조정 — 가로 정렬은 이미 안정.
- 신규 widget 테스트 (높이 안정성 단언) — visual stability는 manual로만 검증, 단순 SizedBox 추가는 자동 테스트 가치 낮음.

## 7. Revision History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| v1.0 | 2026-05-04 | main session | Initial. Plan approved at C:\Users\hyeonha\.claude\plans\vast-yawning-pony.md before co-feature 실행. |
