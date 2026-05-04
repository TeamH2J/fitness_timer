# TRD: timer-stable-layout

- Date: 2026-05-04
- Author: TRD Agent
- Reference: PRD `.claude/outputs/PRD.md`

---

## 1. System Architecture Diagram

No new components. The change is entirely within one method of one existing file.

```
lib/pages/timer_run_page.dart
  └── _TimerRunView.build()
        └── Column.children  ← ONLY CHANGE HERE
              ├── SizedBox(h:22)   wraps Cycle Text         [FR2]
              ├── SizedBox(h:8)    spacer (unchanged)
              ├── SizedBox(h:32)   wraps Phase name Text    [FR2]
              ├── SizedBox(h:24)   spacer (unchanged)
              ├── SizedBox(240×240) ring (unchanged)
              ├── SizedBox(h:16)   spacer (unchanged)
              ├── SizedBox(h:28)   wraps Reps Text or empty [FR1]
              ├── SizedBox(h:24)   spacer (unchanged)
              ├── SizedBox(h:20)   wraps Next Text or empty [FR1]
              └── SizedBox(h:48)   wraps Pause icon or empty[FR1]
```

---

## 2. Tech Stack & Dependencies

No new dependencies. The fix uses `SizedBox`, a core Flutter widget already
present throughout the file.

| Item | Choice | Reason |
|------|--------|--------|
| Language | Dart (existing) | No change |
| Framework | Flutter (existing) | No change |
| New packages | None | PRD NF1, CLAUDE.md §2 |

---

## 3. Module / Component Specification

### `_TimerRunView.build()` — `lib/pages/timer_run_page.dart` lines ~195-281

- **Role:** Renders the full-screen timer UI.
- **Responsibilities (changed):** Wrap five variable-height Column children in
  fixed-height `SizedBox` slots so the Column total height is constant regardless
  of runtime state.
- **Interface:** No signature change. No new classes, functions, or parameters.

Slot mapping after the change:

| Slot height | Content | When child is absent |
|-------------|---------|----------------------|
| 22 | Cycle indicator `Text` (`fontSize 16`, `maxLines: 1`, `overflow: ellipsis`) | always present — no absent case |
| 32 | Phase name `Text` (`fontSize 24`, `maxLines: 1`, `overflow: ellipsis`, `textAlign: center`) | always present — no absent case |
| 28 | Reps target `Text` | `SizedBox(height: 28)` with no child when `snapshot.targetReps == null` |
| 20 | Next-item preview `Text` | `SizedBox(height: 20)` with no child when neither condition holds |
| 48 | Pause `Icon(size: 32)` + `Padding(top: 16)` | `SizedBox(height: 48)` with no child when `state != paused` |

---

## 4. Data Model / Schema

No data model changes. This is a pure widget-layout fix.

---

## 5. API / Interface Specification

No API changes. `TimerRunPage` and `_TimerRunView` public constructors are
unchanged.

---

## 6. Error Handling & Exception Flow

| Scenario | Handling |
|----------|----------|
| `snapshot.targetReps == null` | `SizedBox(height: 28)` renders with no child — zero semantics node, zero paint cost |
| Neither `nextPhase == rest` nor `nextItem != null` | `SizedBox(height: 20)` renders with no child |
| `state != TimerState.paused` | `SizedBox(height: 48)` renders with no child |
| Text overflow in cycle / phase name | `maxLines: 1` + `TextOverflow.ellipsis` — text clips rather than wraps, height stays fixed |

No new exception paths are introduced.

---

## 7. Test Strategy

### Regression (required)

**`test/pages/timer_run_page_color_test.dart`** — existing 5 test cases (T6.1–T6.5)
must pass without modification. These tests pump `TimerRunPage` with each
`TimerPhase` and assert `CircularProgressPainter.foreground`. The layout change
does not affect the painter or the `CustomPaint` lookup.

Verify: `flutter test test/pages/timer_run_page_color_test.dart` → 5/5 pass.

### Static Analysis (required)

`flutter analyze` → 0 errors, 0 warnings after the edit (PRD NF2).

### New Widget Tests

None. Per PRD §6 and the explicit caller instruction, visual layout stability
cannot be meaningfully asserted in widget tests, and the mechanical `SizedBox`
wrapping does not warrant new test code.

---

## 8. Security Considerations

Not applicable. This change is a local widget layout adjustment with no data
input, no network calls, and no state persistence.
