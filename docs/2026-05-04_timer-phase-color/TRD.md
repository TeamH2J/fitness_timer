# TRD: timer-phase-color

- Date: 2026-05-04
- Author: TRD Agent
- Reference: PRD `.claude/outputs/PRD.md`

---

## 1. System Architecture Diagram

No new components are introduced. The change is confined to one call site inside
`_TimerRunView` (a private widget class in `lib/pages/timer_run_page.dart`).

```
timerEngineProvider (Riverpod)
        │
        │  TimerSnapshot { phase, remainingMs, totalMs, … }
        ▼
_TimerRunView.build()
        │
        ├─ _phaseLabel(snapshot.phase)   ← unchanged
        │
        ├─ _phaseColor(snapshot.phase)   ← NEW private method (same pattern as _phaseLabel)
        │         │
        │         └─ returns const Color
        │
        ▼
CircularProgressPainter(
  foreground: _phaseColor(snapshot.phase),   ← only changed line (was: colorScheme.primary)
  background: Colors.white12,                ← unchanged
  strokeWidth: 12,                           ← unchanged
)
```

---

## 2. Tech Stack & Dependencies

| Item | Choice | Reason |
|------|--------|--------|
| Language | Dart (existing) | No change |
| Framework | Flutter (existing) | No change |
| State management | Riverpod `timerEngineProvider` (existing) | `TimerSnapshot.phase` already exposed reactively; no new provider needed |
| New packages | None | O(1) switch over an existing enum — no additional dependency needed |

---

## 3. Module / Component Specification

### `_TimerRunView` (lib/pages/timer_run_page.dart)

- Role: Renders the live timer UI including the circular ring.
- Responsibilities after change:
  - All existing responsibilities unchanged.
  - Adds one private method `_phaseColor(TimerPhase? phase)` that maps each
    `TimerPhase` value to a `Color` constant and returns a fallback for `null`.
  - Passes the returned `Color` to `CircularProgressPainter.foreground` at line 233
    instead of `colorScheme.primary`.
- Interface: Internal to `timer_run_page.dart`; not exposed outside the file.
- Pattern: mirrors the existing `_phaseLabel(TimerPhase? phase, AppLocalizations l10n)`
  method in the same class (NF5 in PRD).

### `CircularProgressPainter` (lib/widgets/circular_progress_painter.dart)

- Role: Unchanged — draws the circular progress arc.
- Responsibilities: Unchanged.
- Interface: Unchanged — the `foreground: Color` parameter already exists and
  `shouldRepaint` already compares it, so color changes trigger repaints automatically.

---

## 4. Data Model / Schema

No data model changes. `TimerPhase` and `TimerSnapshot` are read-only from this
feature's perspective.

### Phase → Color mapping (compile-time constants; not persisted)

| TimerPhase | Hex | dart `Color` constant | Semantic intent |
|------------|-----|-----------------------|----------------|
| `prep` | `#FFB300` | `Color(0xFFFFB300)` | Amber — about to start |
| `work` | `#FF5252` | `Color(0xFFFF5252)` | Red — effort (preserves current colour) |
| `rest` | `#4CAF50` | `Color(0xFF4CAF50)` | Green — recovery |
| `cooldown` | `#26C6DA` | `Color(0xFF26C6DA)` | Cyan — winding down |
| `null` (idle / completed) | `#FF5252` | `Color(0xFFFF5252)` | Fallback to work red |

---

## 5. API / Interface Specification

No public API surface changes. This is a purely intra-widget modification.

### Internal method added

```
Color _phaseColor(TimerPhase? phase)
```

- Declared inside `_TimerRunView`, immediately alongside `_phaseLabel`.
- Pure function; no side effects, no external dependencies.
- Called exactly once: as the `foreground` argument to `CircularProgressPainter`
  at the existing call site (timer_run_page.dart line 233).

---

## 6. Error Handling & Exception Flow

| Scenario | Handling | User-visible effect |
|----------|----------|---------------------|
| `snapshot.phase == null` (idle / completed) | `_phaseColor` returns fallback `Color(0xFFFF5252)` (work red) | Ring renders in red — visually identical to previous behaviour; no regression |
| Future `TimerPhase` value added without updating `_phaseColor` | Dart exhaustive-switch lint warning at compile time; caught by `flutter analyze` (PRD NF3) before any release | N/A — static-analysis gate |

---

## 7. Test Strategy

### Widget Test

One new widget test in `test/pages/timer_run_page_color_test.dart`:

- Pump `TimerRunPage` (or `_TimerRunView` if extractable) with a mocked
  `timerEngineProvider` override for each of the five cases:
  `TimerPhase.prep`, `TimerPhase.work`, `TimerPhase.rest`,
  `TimerPhase.cooldown`, and `null`.
- Find the `CustomPaint` widget and cast its `painter` to `CircularProgressPainter`.
- Assert `painter.foreground == expectedColor` for each case.
- Coverage goal: all five branches of `_phaseColor` — 100 % of the new code path.

### Static Analysis

```
flutter analyze
```

Must report 0 errors and 0 warnings before the PR is raised (CLAUDE.md §7 / PRD NF3).
No integration tests, golden tests, or CI pipeline changes are needed for this
UI-only, single-method addition.

---

## 8. Security Considerations

| Threat | Relevance | Mitigation |
|--------|-----------|------------|
| SQL Injection | Not applicable — no persistence change | — |
| XSS | Not applicable — native Flutter app, no web surface | — |
| Auth bypass | Not applicable — no auth-related change | — |
| Colour spoofing via user input | Not applicable — colour constants are compile-time literals derived only from `TimerPhase` enum values, never from user-supplied data | — |
