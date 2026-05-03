Reset a specific workflow stage back to `pending` in `.claude/state/workflow_state.json` so it can be re-run.

## Usage

```
/workflow-reset [stage]
```

Valid stage values: `planning`, `trd`, `coding`, `review`, `merge`

If no stage argument is provided, ask the user which stage to reset.

## Steps

1. Read `.claude/state/workflow_state.json`
2. Display the current status of all stages
3. Confirm the target stage with the user if not provided as argument
4. Apply the reset:

### Per-stage reset rules

| Stage | Fields to reset |
|-------|----------------|
| `planning` | `stages.planning.status` → `"pending"`, `stages.planning.prd_feedback` → `null` |
| `trd` | `stages.trd.status` → `"pending"` |
| `coding` | `stages.coding.status` → `"pending"`, `stages.coding.review_feedback` → `null` |
| `review` | `stages.review.status` → `"pending"`, `stages.review.previous_feedback_items` → `null` |
| `merge` | `stages.merge.status` → `"pending"` |

5. Set `current_stage` → target stage name
6. Update `updated_at` → current ISO 8601 timestamp
7. Write updated JSON back to file

## Output Format

```
=== Workflow Reset ===

초기화 대상: coding
이전 상태: done → 새 상태: pending

변경 내용:
  stages.coding.status        : "done"  →  "pending"
  stages.coding.review_feedback: "..."  →  null
  current_stage               : "done"  →  "coding"
  updated_at                  : 업데이트됨

✅ workflow_state.json 저장 완료
   이제 Team Lead를 실행하거나 해당 에이전트를 재시작하세요.
```

## Notes
- Only resets the specified stage — does NOT reset later stages automatically
- Does NOT delete branches or close PRs — Git state is unchanged
- Only the `current_stage` field is updated to reflect the reset stage; downstream stage statuses are untouched
- If `current_stage` is already `"done"` and you reset `coding`, the workflow will resume from coding on next Team Lead run
