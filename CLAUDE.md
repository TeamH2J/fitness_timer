# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 5. File Paths

Documents go in the `\docs` folder.

**Codebase navigation**: 클래스/파일/도메인을 `lib/` 내에서 찾을 때는 먼저 `docs/guidelines/CODEBASE_MAP.md`를 참조한다 — 폴더 트리, 도메인 맵, 명명 규칙, "어디에 추가할까?" 가이드, 핵심 클래스↔파일 lookup이 정리되어 있음.

## 6. Multi-Agent Role Boundaries

5-agent 워크플로 규약, 각 agent의 ✅/❌ 경계, 자동화된 시퀀스 다이어그램은 `docs/guidelines/MULTI_AGENT_WORKFLOW.md`를 참조한다.

### Common Violation Detection Criteria (모든 agent 공통)
- 자신의 출력물이 아닌 파일을 만들거나 수정하면 즉시 중단
- 다음 단계에 속하는 작업을 수행하면 즉시 중단
- `workflow_state.json`의 `current_stage`는 Team Lead만 갱신
- 각 agent는 자기 단계의 `status`만 갱신

## 7. Flutter & Dart Compilation Safety
**All code must compile and pass static analysis without errors.**
- **Run Analyzer Before Commit:** 코드를 수정하거나 작성한 후에는 반드시 터미널에서 `flutter analyze`를 실행하고, 경고(Warnings)와 에러(Errors)가 없는지 확인할 것.

## 8. Branch Strategy

**`main` + `develop` 2-tier 모델.** 상세 브랜치 표·흐름·전체 규칙은 `docs/guidelines/BRANCH_STRATEGY.md` 참조.

### Critical Rules (PR 생성 시 매번 확인)
- `main`, `develop`에 **직접 push 금지** — 항상 PR.
- 모든 신규 PR의 base = **`develop`** (hotfix 제외).
- ⚠️ release PR (`develop` → `main`) 머지 시 **`--delete-branch` 절대 금지** (사고 사례: PR #49). feature PR (`feature/*` → `develop`) 머지에만 허용.
