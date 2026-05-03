Read `.claude/state/workflow_state.json` and display the current workflow status as a formatted dashboard.

## Steps

1. Read `.claude/state/workflow_state.json`
2. Format and print the dashboard below

## Output Format

```
╔══════════════════════════════════════════╗
║         Workflow Status Dashboard        ║
╚══════════════════════════════════════════╝

🆔 Workflow ID : <workflow_id>
📌 Feature     : <feature_name>
🌿 Branch      : <branch_name>
🔗 PR          : <pr_number if not null, else "없음"> (<pr_url if available>)
📦 Archive     : <archive_path if not null, else "미생성">
🕒 Updated     : <updated_at>

── Stage Progress ──────────────────────────

  [1] Planning  <status_icon> <status>   (<prd_version>)
  [2] TRD       <status_icon> <status>
  [3] Coding    <status_icon> <status>
  [4] Review    <status_icon> <status>
  [5] Merge     <status_icon> <status>   (<merged_at if available>)

── Current Stage ───────────────────────────
  👉 <current_stage>

── Review Info ─────────────────────────────
  반복: <review_iteration> / <max_review_iterations>
  PRD 반복: <prd_iteration> / <max_prd_iterations>
```

### Status Icons
| status | icon |
|--------|------|
| pending | ⏳ |
| done | ✅ |
| approved | ✅ |
| changes_requested | 🔄 |
| escalated | ⚠️ |
| (missing/null) | ➖ |

## Notes
- If `workflow_state.json` does not exist, print: `⚠️ workflow_state.json 파일이 없습니다. 워크플로우가 아직 시작되지 않았습니다.`
- Do not modify any files — read only.
