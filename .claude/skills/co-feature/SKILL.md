---
name: co-feature
description: Collaborative feature workflow — main Claude plans WITH the user, delegates coding/review to subagents, then performs final check and merge. Use when the user wants to start a new feature with human-in-the-loop planning and pre-merge review (unlike the fully-automated /new-feature).
---

# /co-feature

Unlike `/new-feature` (which hands off to the fully-automated `team-lead` agent), `/co-feature` keeps the main Claude session as the orchestrator. The main session replaces the Planning Agent and performs the final pre-merge review itself.

## Usage

```
/co-feature <feature description>
```

Example:
```
/co-feature 홈 화면에 최근 검진 요약 카드 추가
```

## Steps (the main Claude session must follow these)

### 1. Initialize state

Generate UUID, derive kebab-case `feature_name`, set `branch_name = feature/<feature_name>`, then write `.claude/state/workflow_state.json`:

```json
{
  "workflow_id": "<UUID>",
  "feature_name": "<kebab-case>",
  "created_at": "<ISO 8601 now>",
  "updated_at": "<ISO 8601 now>",
  "current_stage": "planning",
  "branch_name": "feature/<kebab-case>",
  "pr_number": null,
  "archive_path": null,
  "prd_iteration": 0,
  "max_prd_iterations": 3,
  "review_iteration": 0,
  "max_review_iterations": 3,
  "mode": "co-feature",
  "stages": {
    "planning": { "status": "pending", "prd_version": "v1.0", "input": { "requirements": "<user description>" }, "output": ".claude/outputs/PRD.md", "prd_feedback": null },
    "trd":      { "status": "pending", "output": ".claude/outputs/TRD.md" },
    "coding":   { "status": "pending", "pr_url": null, "review_feedback": null, "previous_feedback_items": null },
    "review":   { "status": "pending", "previous_feedback_items": null },
    "merge":    { "status": "pending" }
  }
}
```

If a workflow already exists with `current_stage != "done"`, warn and ask before overwriting.

### 2. Author the PRD with the user (DO NOT call planning-agent)

- Talk with the user directly. Use `AskUserQuestion` to resolve ambiguity (scope, acceptance criteria, out-of-scope items).
- Write `.claude/outputs/PRD.md` directly using the standard Planning Agent format — 6 sections:
  1. Overview
  2. Goals
  3. User Stories
  4. Functional Requirements
  5. Non-Functional Requirements
  6. Out of Scope
  Plus `## 7. Revision History` (start at v1.0).
- Show the user a summary and ask for approval. Revise in place if requested (bump to v1.1 etc.).
- After approval: set `stages.planning.status = "done"`, `current_stage = "trd"`, update `updated_at`.

### 3. Generate the TRD via subagent

Call:
```
Agent(subagent_type="trd-agent",
      prompt="feature_name: <name>\nworkflow_id: <id>")
```

After it returns, read `.claude/outputs/TRD.md` and present a 3–5 line summary (architecture / key files / test strategy) to the user. Wait for approval before continuing. Set `current_stage = "coding"`.

### 4. Archive PRD/TRD

Create `docs/<YYYY-MM-DD>_<feature-name>/` and copy `PRD.md` + `TRD.md` into it. Record the path in `archive_path`.

### 5. Implement via code-agent

Call:
```
Agent(subagent_type="code-agent",
      prompt="feature_name: <name>\nworkflow_id: <id>\nbranch_name: <branch>\nreview_feedback: (empty)")
```

When it returns, extract the PR number/URL from its output and write to `stages.coding.pr_url` and top-level `pr_number`. Set `stages.coding.status = "done"`, `current_stage = "review"`.

### 6. Review via review-agent

Call:
```
Agent(subagent_type="review-agent",
      prompt="feature_name: <name>\nworkflow_id: <id>\npr_number: <pr>\nprevious_feedback: (none)")
```

Capture its decision (`approve` or `changes_requested`) and feedback.

### 7. Main Claude final check

- Run `gh pr view <pr_number> --json title,body,files,additions,deletions` and `gh pr diff <pr_number>` to inspect the changes yourself.
- Summarize for the user:
  - review-agent's verdict and key feedback
  - Your own additional observations (if any)
  - PR stats (files / +lines / -lines)
- Use `AskUserQuestion` with three options:
  - **머지** — proceed to merge
  - **수정 요청** — collect specific feedback from the user, return to step 5
  - **취소** — stop without merging

### 8. Branch on user decision

- **머지 (merge)**:
  ```bash
  gh pr merge <pr_number> --squash --delete-branch
  ```
  > ⚠️ **Scope:** This merge handles **feature PRs only** (`base = develop`). Release PRs (`develop` → `main`) must NOT use `--delete-branch` — it would delete the long-lived `develop` branch (per CLAUDE.md §8).

  Set `stages.merge.status = "done"`, `current_stage = "done"`. Print final summary.

- **수정 요청 (request changes)**:
  - Write the user's feedback (plus any review-agent feedback) into `stages.coding.review_feedback`.
  - Copy current `stages.coding.review_feedback` → `stages.coding.previous_feedback_items` (carry-forward) before re-running.
  - Increment `review_iteration`. If `review_iteration >= max_review_iterations` (3), escalate to user and stop.
  - Re-run step 5 (code-agent with `review_feedback` populated), then step 6 (review-agent with `previous_feedback`), then step 7 again.

- **취소 (cancel)**: Leave state as-is; tell the user they can resume via `/workflow-status` or reset via `/workflow-reset`.

## Notes

- This skill replaces only the Planning Agent role with the main Claude session and adds a human-in-the-loop final check before merge. trd-agent / code-agent / review-agent are reused unchanged.
- Use `Agent(...)` calls (not the fully-automated `team-lead` agent). The main session owns orchestration.
- Always update `updated_at` whenever you mutate `workflow_state.json`.
- Do not skip pre-commit hooks or push directly to `main` or `develop` — always go through a PR.
